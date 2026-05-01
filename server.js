const express = require("express");
const fs = require("fs");
const path = require("path");
const { execFile } = require("child_process");

const app = express();
const PORT = process.env.PORT || 3000;
const OUTPUT_DIR = path.join(__dirname, "output");
const TRASH_DIR = path.join(__dirname, "trash");
const FAVORITES_FILE = path.join(OUTPUT_DIR, "favorites.json");

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

function readFavorites() {
  if (!fs.existsSync(FAVORITES_FILE)) return [];
  try {
    return JSON.parse(fs.readFileSync(FAVORITES_FILE, "utf-8"));
  } catch {
    return [];
  }
}

function writeFavorites(favs) {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  fs.writeFileSync(FAVORITES_FILE, JSON.stringify(favs, null, 2));
}

function loadSound(batch, name) {
  const jsonPath = path.join(OUTPUT_DIR, batch, `${name}.json`);
  if (!fs.existsSync(jsonPath)) return null;
  return JSON.parse(fs.readFileSync(jsonPath, "utf-8"));
}

// List all batches, newest first
app.get("/api/batches", (req, res) => {
  if (!fs.existsSync(OUTPUT_DIR)) return res.json([]);

  const entries = fs.readdirSync(OUTPUT_DIR, { withFileTypes: true });
  const batches = entries
    .filter((e) => e.isDirectory())
    .filter((e) => {
      const dir = path.join(OUTPUT_DIR, e.name);
      try {
        return fs.readdirSync(dir).some((f) => f.endsWith(".json"));
      } catch {
        return false;
      }
    })
    .map((e) => e.name)
    .sort()
    .reverse();

  res.json(batches);
});

// List all sounds in a batch
app.get("/api/sounds", (req, res) => {
  const batch = req.query.batch;
  if (!batch) return res.status(400).json({ error: "batch parameter required" });

  const batchDir = path.join(OUTPUT_DIR, batch);
  if (!fs.existsSync(batchDir)) return res.status(404).json({ error: "batch not found" });

  const files = fs.readdirSync(batchDir).filter((f) => f.endsWith(".json"));
  const sounds = files.map((f) => {
    const content = fs.readFileSync(path.join(batchDir, f), "utf-8");
    return JSON.parse(content);
  });

  res.json(sounds);
});

// Get a single sound's metadata
app.get("/api/sounds/:batch/:name", (req, res) => {
  const jsonPath = path.join(OUTPUT_DIR, req.params.batch, `${req.params.name}.json`);
  if (!fs.existsSync(jsonPath)) return res.status(404).json({ error: "sound not found" });

  const content = fs.readFileSync(jsonPath, "utf-8");
  res.json(JSON.parse(content));
});

// Serve audio and other files from batch directories
app.get("/audio/:batch/:filename", (req, res) => {
  const filePath = path.join(OUTPUT_DIR, req.params.batch, req.params.filename);
  if (!fs.existsSync(filePath)) return res.status(404).send("not found");

  res.sendFile(filePath);
});

// Trigger sound generation
app.post("/api/generate", (req, res) => {
  const body = req.body || {};
  const { count, types, duration, formats, freq } = body;
  const args = [path.join(__dirname, "generate.rb")];

  if (count) args.push("--count", String(count));
  if (types) args.push("--types", types);
  if (duration) args.push("--duration", String(duration));
  if (formats) args.push("--formats", formats);
  if (freq) args.push("--freq", String(freq));

  console.log("Running: ruby", args.join(" "));

  execFile("ruby", args, { timeout: 120000 }, (err, stdout, stderr) => {
    if (err) {
      console.error("Generate failed:", err.message);
      return res.status(500).json({ error: err.message, output: (stdout || "") + (stderr || "") });
    }
    // Extract batch name from output (last line like "Batch complete: .../2026-04-08_235447")
    const match = stdout.match(/Batch complete: .*\/(\S+)/);
    const batch = match ? match[1] : null;
    res.json({ batch, output: stdout });
  });
});

// List favorited sounds (with full metadata)
app.get("/api/favorites", (req, res) => {
  const favs = readFavorites();
  const sounds = [];
  for (const f of favs) {
    const sound = loadSound(f.batch, f.name);
    if (sound) sounds.push({
      ...sound,
      batch: f.batch,
      favorited_at: f.favorited_at,
      favorite_title: f.title || null,
    });
  }
  // Newest favorites first
  sounds.sort((a, b) => (b.favorited_at || "").localeCompare(a.favorited_at || ""));
  res.json(sounds);
});

// Toggle/add favorite
app.post("/api/favorites", (req, res) => {
  const { batch, name, title } = req.body || {};
  if (!batch || !name) return res.status(400).json({ error: "batch and name required" });
  if (!loadSound(batch, name)) return res.status(404).json({ error: "sound not found" });

  const favs = readFavorites();
  const existing = favs.find((f) => f.batch === batch && f.name === name);
  if (existing) {
    if (typeof title === "string") existing.title = title.trim() || undefined;
    writeFavorites(favs);
  } else {
    const entry = { batch, name, favorited_at: new Date().toISOString() };
    if (typeof title === "string" && title.trim()) entry.title = title.trim();
    favs.push(entry);
    writeFavorites(favs);
  }
  res.json({ favorited: true });
});

// Update title on an existing favorite
app.patch("/api/favorites/:batch/:name", (req, res) => {
  const { batch, name } = req.params;
  const { title } = req.body || {};
  const favs = readFavorites();
  const fav = favs.find((f) => f.batch === batch && f.name === name);
  if (!fav) return res.status(404).json({ error: "favorite not found" });

  if (typeof title === "string") {
    const trimmed = title.trim();
    if (trimmed) fav.title = trimmed;
    else delete fav.title;
  }
  writeFavorites(favs);
  res.json({ favorited: true, title: fav.title || null });
});

app.delete("/api/favorites/:batch/:name", (req, res) => {
  const { batch, name } = req.params;
  const favs = readFavorites().filter((f) => !(f.batch === batch && f.name === name));
  writeFavorites(favs);
  res.json({ favorited: false });
});

// Soft-delete (move to trash/) all non-favorited sounds. Body { batch? } scopes to one batch.
app.post("/api/cleanup", (req, res) => {
  const { batch } = req.body || {};
  if (!fs.existsSync(OUTPUT_DIR)) return res.json({ moved: 0, batches_emptied: 0 });

  const favSet = new Set(readFavorites().map((f) => `${f.batch}::${f.name}`));

  let batches;
  if (batch) {
    batches = [batch];
  } else {
    batches = fs.readdirSync(OUTPUT_DIR, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name);
  }

  let moved = 0;
  let emptied = 0;

  for (const b of batches) {
    const batchDir = path.join(OUTPUT_DIR, b);
    if (!fs.existsSync(batchDir) || !fs.statSync(batchDir).isDirectory()) continue;

    const files = fs.readdirSync(batchDir);
    const jsonNames = files.filter((f) => f.endsWith(".json")).map((f) => f.slice(0, -5));
    const keptNames = new Set(jsonNames.filter((n) => favSet.has(`${b}::${n}`)));
    const trashBatchDir = path.join(TRASH_DIR, b);

    for (const f of files) {
      // Map a file to its sound name: strip the last extension.
      const dot = f.lastIndexOf(".");
      const name = dot === -1 ? f : f.slice(0, dot);
      if (keptNames.has(name)) continue;

      fs.mkdirSync(trashBatchDir, { recursive: true });
      fs.renameSync(path.join(batchDir, f), path.join(trashBatchDir, f));
      if (f.endsWith(".json")) moved++;
    }

    const remaining = fs.readdirSync(batchDir);
    if (remaining.length === 0) {
      fs.rmdirSync(batchDir);
      emptied++;
    }
  }

  res.json({ moved, batches_emptied: emptied });
});

app.listen(PORT, () => {
  console.log(`Sound Explorer running at http://localhost:${PORT}`);
});
