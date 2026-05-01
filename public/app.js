let currentAudio = null;
let currentPlayBtn = null;
let favoritesSet = new Set();
let favoriteTitles = new Map(); // key -> title
let favoritesCache = []; // last loaded favorites list (sounds with .batch and .synth_type)
let currentView = null; // { kind: "batch", batch } | { kind: "favorites", group?, type? }

function favKey(batch, name) {
  return `${batch}::${name}`;
}

// User-friendly labels for each synth type pill.
const TYPE_LABELS = {
  fm: "FM",
  subtractive: "Subtractive",
  additive: "Additive",
  granular: "Granular",
  karplus: "Karplus",
  modal: "Modal",
  drum: "Drum",
  physical: "Physical",
  formant: "Formant",
  noise: "Noise",
  stochastic: "Stochastic",
  waveshape: "Waveshape",
  ringmod: "Ring mod",
  granular_sample: "Granular (sample)",
  timestretch: "Time stretch",
  spectral_morph: "Spectral morph",
  cross_synth: "Cross synth",
  convolution: "Convolution"
};

const TYPE_GROUPS = {
  classic: ["fm", "subtractive", "additive", "granular"],
  percussive: ["karplus", "modal", "drum", "physical"],
  vocal: ["formant", "noise", "stochastic"],
  distortion: ["waveshape", "ringmod"],
  samples: ["granular_sample", "timestretch", "spectral_morph", "cross_synth", "convolution"],
};

const GROUP_LABELS = {
  classic: "Classic",
  percussive: "Percussive & Physical",
  vocal: "Vocal & Texture",
  distortion: "Distortion & Spectral",
  samples: "Sample-based",
};

const TYPE_TO_GROUP = {};
for (const [g, ts] of Object.entries(TYPE_GROUPS)) ts.forEach((t) => (TYPE_TO_GROUP[t] = g));

const SAMPLE_BASED_TYPES = new Set(TYPE_GROUPS.samples);

const STORAGE_KEY = "sound-explorer.selected-types";
const BAR_HIDDEN_KEY = "sound-explorer.gen-bar-hidden";
const TAB_KEY = "sound-explorer.active-tab";

let lastBatch = null;
let lastFavFilter = {};

function buildTypePills() {
  const saved = loadSavedTypes();

  document.querySelectorAll(".type-pills").forEach((container) => {
    const types = container.dataset.types.split(",");
    types.forEach((t) => {
      const label = document.createElement("label");
      label.className = "type-pill";
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.value = t;
      // Default: pure types selected, sample-based unselected.
      const defaultChecked = !SAMPLE_BASED_TYPES.has(t);
      checkbox.checked = saved ? saved.includes(t) : defaultChecked;
      checkbox.addEventListener("change", () => {
        label.classList.toggle("checked", checkbox.checked);
        saveSelectedTypes();
      });
      if (checkbox.checked) label.classList.add("checked");
      label.appendChild(checkbox);
      label.appendChild(document.createTextNode(TYPE_LABELS[t] || t));
      container.appendChild(label);
    });
  });
}

function loadSavedTypes() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveSelectedTypes() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(getSelectedTypes()));
  } catch {}
}

function getSelectedTypes() {
  return Array.from(document.querySelectorAll(".type-pill input"))
    .filter((c) => c.checked)
    .map((c) => c.value);
}

function selectTypes(mode) {
  document.querySelectorAll(".type-pill input").forEach((checkbox) => {
    const t = checkbox.value;
    let checked;
    switch (mode) {
      case "all":     checked = true; break;
      case "none":    checked = false; break;
      case "pure":    checked = !SAMPLE_BASED_TYPES.has(t); break;
      case "samples": checked = SAMPLE_BASED_TYPES.has(t); break;
      default:        checked = checkbox.checked;
    }
    checkbox.checked = checked;
    checkbox.parentElement.classList.toggle("checked", checked);
  });
  saveSelectedTypes();
}

function toggleGenerateBar() {
  const bar = document.getElementById("generate-bar");
  const btn = document.getElementById("gen-bar-toggle");
  const hidden = bar.classList.toggle("hidden");
  btn.textContent = hidden ? "Show" : "Hide";
  try {
    localStorage.setItem(BAR_HIDDEN_KEY, hidden ? "1" : "0");
  } catch {}
}

function restoreBarState() {
  try {
    if (localStorage.getItem(BAR_HIDDEN_KEY) === "1") {
      document.getElementById("generate-bar").classList.add("hidden");
      document.getElementById("gen-bar-toggle").textContent = "Show";
    }
  } catch {}
}

async function loadFavorites({ render } = { render: false }) {
  const res = await fetch("/api/favorites");
  const sounds = await res.json();
  favoritesCache = sounds;
  favoritesSet = new Set(sounds.map((s) => favKey(s.batch, s.name)));
  favoriteTitles = new Map(
    sounds.filter((s) => s.favorite_title).map((s) => [favKey(s.batch, s.name), s.favorite_title])
  );
  document.getElementById("tab-fav-count").textContent =
    sounds.length ? `(${sounds.length})` : "";
  renderFavoritesNav();
  if (render) renderFavoritesView();
  return sounds;
}

function getActiveTab() {
  try {
    return localStorage.getItem(TAB_KEY) || "batches";
  } catch {
    return "batches";
  }
}

function setActiveTab(tab, { loadView = true } = {}) {
  document.querySelectorAll(".sidebar-tab").forEach((b) => {
    b.classList.toggle("active", b.dataset.tab === tab);
  });
  document.querySelectorAll(".sidebar-pane").forEach((p) => {
    p.classList.toggle("active", p.id === `sidebar-pane-${tab}`);
  });
  try { localStorage.setItem(TAB_KEY, tab); } catch {}

  if (!loadView) return;

  if (tab === "favorites") {
    selectFavorites(lastFavFilter);
  } else {
    if (lastBatch) {
      const li = [...document.querySelectorAll("#batch-list li")].find(
        (el) => el.textContent === lastBatch
      );
      if (li) selectBatch(lastBatch, li);
    } else {
      const first = document.querySelector("#batch-list li");
      if (first) selectBatch(first.textContent, first);
    }
  }
}

function renderFavoritesNav() {
  const nav = document.getElementById("favorites-nav");
  const sounds = favoritesCache;

  // Counts per group / type
  const groupCounts = {};
  const typeCounts = {};
  for (const s of sounds) {
    const g = TYPE_TO_GROUP[s.synth_type] || "other";
    groupCounts[g] = (groupCounts[g] || 0) + 1;
    typeCounts[s.synth_type] = (typeCounts[s.synth_type] || 0) + 1;
  }

  const isActive = (pred) =>
    currentView && currentView.kind === "favorites" && pred ? "active" : "";

  const allActive = isActive(!currentView?.group && !currentView?.type);

  let html = `<li class="fav-nav-all ${allActive}" data-action="all">★ All favorites${
    sounds.length ? ` <span class="favorites-count">(${sounds.length})</span>` : ""
  }</li>`;

  for (const groupKey of Object.keys(TYPE_GROUPS)) {
    const gCount = groupCounts[groupKey];
    if (!gCount) continue;
    const gActive = isActive(currentView?.group === groupKey && !currentView?.type);
    html += `<li class="fav-nav-group ${gActive}" data-action="group" data-group="${groupKey}">${esc(
      GROUP_LABELS[groupKey]
    )} <span class="favorites-count">(${gCount})</span></li>`;

    for (const t of TYPE_GROUPS[groupKey]) {
      const tCount = typeCounts[t];
      if (!tCount) continue;
      const tActive = isActive(currentView?.type === t);
      html += `<li class="fav-nav-type ${tActive}" data-action="type" data-type="${t}">${esc(
        TYPE_LABELS[t] || t
      )} <span class="favorites-count">(${tCount})</span></li>`;
    }
  }

  // Empty state
  if (sounds.length === 0) {
    html = `<li class="fav-nav-all ${allActive}" data-action="all">★ All favorites</li>`;
  }

  nav.innerHTML = html;
  nav.querySelectorAll("li").forEach((li) => {
    li.addEventListener("click", () => {
      const action = li.dataset.action;
      if (action === "all") selectFavorites();
      else if (action === "group") selectFavorites({ group: li.dataset.group });
      else if (action === "type") selectFavorites({ type: li.dataset.type });
    });
  });
}

function renderFavoritesView() {
  const container = document.getElementById("sounds");
  let sounds = favoritesCache;

  if (currentView?.type) {
    sounds = sounds.filter((s) => s.synth_type === currentView.type);
  } else if (currentView?.group) {
    sounds = sounds.filter((s) => TYPE_TO_GROUP[s.synth_type] === currentView.group);
  }

  if (sounds.length === 0) {
    const msg =
      favoritesCache.length === 0
        ? "No favorites yet. Click ★ on a sound to favorite it."
        : "No favorites match this filter.";
    container.innerHTML = `<div class="empty-state">${msg}</div>`;
    return;
  }
  container.innerHTML = sounds.map((s) => cardHTML(s.batch, s)).join("");
}

function selectFavorites(filter = {}) {
  document.querySelectorAll("#batch-list li").forEach((el) => el.classList.remove("active"));
  stopPlayback();
  currentView = { kind: "favorites", ...filter };
  lastFavFilter = filter;
  renderFavoritesNav();
  renderFavoritesView();
}

function onTitleFocus(input) {
  input.dataset.original = input.value;
}

function onTitleKeydown(event, input) {
  if (event.key === "Enter") {
    event.preventDefault();
    input.blur();
  } else if (event.key === "Escape") {
    event.preventDefault();
    input.value = input.dataset.original || "";
    input.blur();
  }
}

async function saveFavoriteTitle(input) {
  const row = input.closest(".fav-title-row");
  const batch = row.dataset.batch;
  const name = row.dataset.name;
  const key = favKey(batch, name);
  const next = input.value.trim();
  const current = favoriteTitles.get(key) || "";
  if (next === current) {
    input.classList.toggle("fav-title-empty", !next);
    return;
  }

  const res = await fetch(
    `/api/favorites/${encodeURIComponent(batch)}/${encodeURIComponent(name)}`,
    {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: next }),
    }
  );
  if (!res.ok) {
    input.value = current;
    return;
  }
  const data = await res.json();
  if (data.title) favoriteTitles.set(key, data.title);
  else favoriteTitles.delete(key);
  input.value = data.title || "";
  input.classList.toggle("fav-title-empty", !data.title);
}

async function toggleFavorite(btn) {
  const batch = btn.dataset.batch;
  const name = btn.dataset.name;
  const key = favKey(batch, name);
  const isFav = favoritesSet.has(key);

  const res = await fetch(
    isFav
      ? `/api/favorites/${encodeURIComponent(batch)}/${encodeURIComponent(name)}`
      : "/api/favorites",
    {
      method: isFav ? "DELETE" : "POST",
      headers: { "Content-Type": "application/json" },
      body: isFav ? undefined : JSON.stringify({ batch, name }),
    }
  );
  if (!res.ok) return;

  if (isFav) favoritesSet.delete(key);
  else favoritesSet.add(key);

  // Update star UI
  btn.classList.toggle("favorited", !isFav);
  btn.textContent = !isFav ? "★" : "☆";
  btn.title = !isFav ? "Unfavorite" : "Favorite";

  // Refresh nav counts and re-render so title input appears/disappears
  if (currentView && currentView.kind === "favorites") {
    await loadFavorites({ render: true });
  } else if (currentView && currentView.kind === "batch") {
    await loadFavorites();
    const sounds = await (await fetch(`/api/sounds?batch=${encodeURIComponent(currentView.batch)}`)).json();
    renderSounds(currentView.batch, sounds);
  }
}

async function loadBatches() {
  const res = await fetch("/api/batches");
  const batches = await res.json();
  const list = document.getElementById("batch-list");

  if (batches.length === 0) {
    document.getElementById("sounds").innerHTML =
      '<div class="empty-state">No batches found. Run <code>ruby generate.rb</code> to create some sounds.</div>';
    return;
  }

  const activeTab = getActiveTab();
  batches.forEach((batch, i) => {
    const li = document.createElement("li");
    li.textContent = batch;
    li.addEventListener("click", () => selectBatch(batch, li));
    list.appendChild(li);

    // Auto-select the newest batch only if we're on the batches tab
    if (i === 0 && activeTab === "batches") selectBatch(batch, li);
  });
}

async function selectBatch(batch, li) {
  // Update sidebar selection
  document.querySelectorAll("#batch-list li").forEach((el) => el.classList.remove("active"));
  document.querySelectorAll("#favorites-nav li").forEach((el) => el.classList.remove("active"));
  li.classList.add("active");

  stopPlayback();
  currentView = { kind: "batch", batch };
  lastBatch = batch;

  const res = await fetch(`/api/sounds?batch=${encodeURIComponent(batch)}`);
  const sounds = await res.json();
  renderSounds(batch, sounds);
}

function renderSounds(batch, sounds) {
  const container = document.getElementById("sounds");

  if (sounds.length === 0) {
    container.innerHTML = '<div class="empty-state">No sounds in this batch.</div>';
    return;
  }

  container.innerHTML = sounds.map((s) => cardHTML(batch, s)).join("");
}

function cardHTML(batch, sound) {
  const params = formatParams(sound);
  const audioFile = sound.files.ogg || sound.files.wav;
  const audioUrl = `/audio/${encodeURIComponent(batch)}/${encodeURIComponent(audioFile)}`;

  const tagsHTML = sound.tags.length
    ? `<div class="tags">${sound.tags.map((t) => `<span class="tag">${esc(t)}</span>`).join("")}</div>`
    : "";

  const descHTML = sound.description
    ? `<div class="description">${esc(sound.description)}</div>`
    : "";

  const key = favKey(batch, sound.name);
  const isFav = favoritesSet.has(key);
  const starChar = isFav ? "★" : "☆";
  const starClass = isFav ? "fav-btn favorited" : "fav-btn";
  const title = favoriteTitles.get(key) || "";

  const titleHTML = isFav
    ? `<div class="fav-title-row" data-batch="${esc(batch)}" data-name="${esc(sound.name)}">
         <input type="text" class="fav-title-input ${title ? "" : "fav-title-empty"}" value="${esc(title)}" placeholder="Untitled — click to name" onfocus="onTitleFocus(this)" onblur="saveFavoriteTitle(this)" onkeydown="onTitleKeydown(event, this)">
       </div>`
    : "";

  return `
    <div class="sound-card" id="card-${esc(sound.name)}">
      <div class="sound-card-header">
        <span class="sound-name">${esc(sound.name)}</span>
        <div class="sound-card-header-right">
          <span class="synth-type">${esc(sound.synth_type)}</span>
          <button class="${starClass}" data-batch="${esc(batch)}" data-name="${esc(sound.name)}" title="${isFav ? "Unfavorite" : "Favorite"}" onclick="toggleFavorite(this)">${starChar}</button>
        </div>
      </div>
      ${titleHTML}
      ${currentView && currentView.kind === "favorites" ? `<div class="sound-batch-ref">${esc(batch)}</div>` : ""}
      <div class="sound-params">${params}</div>
      <div class="sound-controls">
        <button class="play-btn" data-url="${audioUrl}" onclick="togglePlay(this)">Play</button>
        <span class="duration">${sound.duration_seconds}s</span>
        <button class="detail-toggle" onclick="toggleDetail('${esc(sound.name)}')">details</button>
      </div>
      ${tagsHTML}
      ${descHTML}
      <div class="sound-detail">
        <h3>Parameters</h3>
        <pre>${esc(JSON.stringify(sound.params, null, 2))}</pre>
        <h3>CSD</h3>
        <pre>${esc(sound.csd_content)}</pre>
      </div>
    </div>
  `;
}

function formatParams(sound) {
  const p = sound.params;
  const parts = [];

  switch (sound.synth_type) {
    case "fm":
      parts.push(`<span><span class="param-label">carrier</span> ${p.carrier_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">mod ratio</span> ${p.mod_ratio}</span>`);
      parts.push(`<span><span class="param-label">mod index</span> ${p.mod_index}</span>`);
      break;
    case "subtractive":
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">wave</span> ${p.waveform}</span>`);
      parts.push(`<span><span class="param-label">cutoff</span> x${p.filter.cutoff_multiplier}</span>`);
      parts.push(`<span><span class="param-label">reso</span> ${p.filter.resonance}</span>`);
      break;
    case "additive":
      parts.push(`<span><span class="param-label">fundamental</span> ${p.fundamental} Hz</span>`);
      parts.push(`<span><span class="param-label">partials</span> ${p.num_partials}</span>`);
      parts.push(`<span><span class="param-label">rolloff</span> ${p.rolloff_exponent}</span>`);
      break;
    case "granular":
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">density</span> ${p.grain_density}/s</span>`);
      parts.push(`<span><span class="param-label">grain dur</span> ${p.grain_duration}s</span>`);
      parts.push(`<span><span class="param-label">scatter</span> ${p.pitch_scatter_semitones} st</span>`);
      break;
    case "karplus":
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">method</span> ${p.method}</span>`);
      parts.push(`<span><span class="param-label">voices</span> ${p.voices}</span>`);
      break;
    case "modal":
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">preset</span> ${p.preset}</span>`);
      parts.push(`<span><span class="param-label">modes</span> ${p.modes.length}</span>`);
      break;
    case "drum":
      parts.push(`<span><span class="param-label">type</span> ${p.archetype}</span>`);
      parts.push(`<span><span class="param-label">body</span> ${p.body_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">sweep</span> x${p.pitch_sweep_mult}</span>`);
      break;
    case "physical":
      parts.push(`<span><span class="param-label">model</span> ${p.instrument}</span>`);
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">glide</span> ${p.glide_cents}¢</span>`);
      break;
    case "formant":
      parts.push(`<span><span class="param-label">vowel</span> ${p.vowel}</span>`);
      parts.push(`<span><span class="param-label">fund</span> ${p.fundamental} Hz</span>`);
      parts.push(`<span><span class="param-label">vibrato</span> ${p.vibrato.rate} Hz</span>`);
      break;
    case "noise":
      parts.push(`<span><span class="param-label">color</span> ${p.color}</span>`);
      parts.push(`<span><span class="param-label">filter</span> ${p.filter}</span>`);
      parts.push(`<span><span class="param-label">cutoff</span> ${p.cutoff_start}→${p.cutoff_end} Hz</span>`);
      parts.push(`<span><span class="param-label">bw</span> ${p.bandwidth} Hz</span>`);
      break;
    case "stochastic":
      parts.push(`<span><span class="param-label">center</span> ${p.center_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">voices</span> ${p.voice_count}</span>`);
      parts.push(`<span><span class="param-label">flicker</span> ${p.flicker.rate} Hz</span>`);
      break;
    case "waveshape":
      parts.push(`<span><span class="param-label">source</span> ${p.source}</span>`);
      parts.push(`<span><span class="param-label">freq</span> ${p.base_freq} Hz</span>`);
      parts.push(`<span><span class="param-label">drive</span> ${p.drive.start}→${p.drive.end}</span>`);
      break;
    case "ringmod":
      parts.push(`<span><span class="param-label">carrier</span> ${p.carrier_freq} Hz (${p.carrier_wave})</span>`);
      parts.push(`<span><span class="param-label">mod ratio</span> ${p.mod_ratio}</span>`);
      parts.push(`<span><span class="param-label">ring mix</span> ${p.ring_amount}</span>`);
      break;
    case "granular_sample":
      parts.push(`<span><span class="param-label">sample</span> ${p.sample}</span>`);
      parts.push(`<span><span class="param-label">grain size</span> ${p.grain_size}s</span>`);
      parts.push(`<span><span class="param-label">density</span> ${p.grain_density}/s</span>`);
      parts.push(`<span><span class="param-label">pitch</span> ${p.pitch_semitones} st</span>`);
      parts.push(`<span><span class="param-label">read rate</span> ${p.pointer_rate}×</span>`);
      break;
    case "timestretch":
      parts.push(`<span><span class="param-label">sample</span> ${p.sample}</span>`);
      parts.push(`<span><span class="param-label">stretch</span> ${p.stretch}×</span>`);
      parts.push(`<span><span class="param-label">pitch</span> ${p.pitch_semitones} st</span>`);
      parts.push(`<span><span class="param-label">window</span> ${p.start_position}→${p.end_position}s</span>`);
      break;
    case "spectral_morph":
      parts.push(`<span><span class="param-label">A</span> ${p.sample_a}</span>`);
      parts.push(`<span><span class="param-label">B</span> ${p.sample_b}</span>`);
      parts.push(`<span><span class="param-label">shape</span> ${p.morph_shape}</span>`);
      parts.push(`<span><span class="param-label">rate</span> ${p.morph_rate} Hz</span>`);
      break;
    case "cross_synth":
      parts.push(`<span><span class="param-label">excitor</span> ${p.excitor_sample}</span>`);
      parts.push(`<span><span class="param-label">filter</span> ${p.filter_sample}</span>`);
      parts.push(`<span><span class="param-label">cross</span> ${p.cross_amount}</span>`);
      break;
    case "convolution":
      parts.push(`<span><span class="param-label">IR</span> ${p.impulse_response}</span>`);
      parts.push(`<span><span class="param-label">excitation</span> ${p.excitation}</span>`);
      parts.push(`<span><span class="param-label">wet</span> ${p.wet_dry}</span>`);
      break;
  }

  return parts.join("");
}

function togglePlay(btn) {
  const url = btn.dataset.url;

  // If clicking the same button that's playing, stop it
  if (currentPlayBtn === btn && currentAudio) {
    stopPlayback();
    return;
  }

  stopPlayback();

  const audio = new Audio(url);
  currentAudio = audio;
  currentPlayBtn = btn;
  btn.textContent = "Stop";
  btn.classList.add("playing");

  audio.addEventListener("ended", () => {
    btn.textContent = "Play";
    btn.classList.remove("playing");
    currentAudio = null;
    currentPlayBtn = null;
  });

  audio.play();
}

function stopPlayback() {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio.currentTime = 0;
    currentAudio = null;
  }
  if (currentPlayBtn) {
    currentPlayBtn.textContent = "Play";
    currentPlayBtn.classList.remove("playing");
    currentPlayBtn = null;
  }
}

function toggleDetail(name) {
  const card = document.getElementById(`card-${name}`);
  card.classList.toggle("expanded");
}

function esc(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

async function triggerGenerate() {
  const btn = document.getElementById("gen-btn");
  const status = document.getElementById("gen-status");
  const count = document.getElementById("gen-count").value;
  const freqInput = document.getElementById("gen-freq").value;
  const durationInput = document.getElementById("gen-duration").value;

  const selected = getSelectedTypes();
  status.classList.remove("error");

  if (selected.length === 0) {
    status.textContent = "Pick at least one synth type.";
    status.classList.add("error");
    return;
  }

  const body = { count: parseInt(count), types: selected.join(",") };
  if (freqInput) body.freq = parseFloat(freqInput);
  if (durationInput) body.duration = parseFloat(durationInput);

  btn.disabled = true;
  btn.textContent = "Generating...";
  status.textContent = `Generating ${count} sounds across ${selected.length} type${selected.length === 1 ? "" : "s"}...`;

  try {
    const res = await fetch("/api/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      status.textContent = `Server error: ${text.slice(0, 200)}`;
      status.classList.add("error");
      return;
    }

    if (!res.ok) {
      status.textContent = `Error: ${data.error}`;
      status.classList.add("error");
      return;
    }

    // Refresh batch list and select the new batch
    const list = document.getElementById("batch-list");
    list.innerHTML = "";
    await loadBatches();

    status.textContent = `Created ${data.batch}`;
  } catch (e) {
    status.textContent = `Error: ${e.message}`;
    status.classList.add("error");
  } finally {
    btn.disabled = false;
    btn.textContent = "Generate";
  }
}

buildTypePills();
restoreBarState();

document.querySelectorAll(".sidebar-tab").forEach((btn) => {
  btn.addEventListener("click", () => setActiveTab(btn.dataset.tab));
});

setActiveTab(getActiveTab(), { loadView: false });
loadFavorites().then(async () => {
  await loadBatches();
  if (getActiveTab() === "favorites") selectFavorites();
});
