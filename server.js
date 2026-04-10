const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const OUTPUT_DIR = path.join(__dirname, "output");

app.use(express.static(path.join(__dirname, "public")));

// List all batches, newest first
app.get("/api/batches", (req, res) => {
  if (!fs.existsSync(OUTPUT_DIR)) return res.json([]);

  const entries = fs.readdirSync(OUTPUT_DIR, { withFileTypes: true });
  const batches = entries
    .filter((e) => e.isDirectory())
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

app.listen(PORT, () => {
  console.log(`Sound Explorer running at http://localhost:${PORT}`);
});
