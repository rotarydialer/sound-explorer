let currentAudio = null;
let currentPlayBtn = null;

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

const SAMPLE_BASED_TYPES = new Set([
  "granular_sample", "timestretch", "spectral_morph", "cross_synth", "convolution"
]);

const STORAGE_KEY = "sound-explorer.selected-types";
const BAR_HIDDEN_KEY = "sound-explorer.gen-bar-hidden";

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

async function loadBatches() {
  const res = await fetch("/api/batches");
  const batches = await res.json();
  const list = document.getElementById("batch-list");

  if (batches.length === 0) {
    document.getElementById("sounds").innerHTML =
      '<div class="empty-state">No batches found. Run <code>ruby generate.rb</code> to create some sounds.</div>';
    return;
  }

  batches.forEach((batch, i) => {
    const li = document.createElement("li");
    li.textContent = batch;
    li.addEventListener("click", () => selectBatch(batch, li));
    list.appendChild(li);

    // Auto-select the newest batch
    if (i === 0) selectBatch(batch, li);
  });
}

async function selectBatch(batch, li) {
  // Update sidebar selection
  document.querySelectorAll("#batch-list li").forEach((el) => el.classList.remove("active"));
  li.classList.add("active");

  stopPlayback();

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

  return `
    <div class="sound-card" id="card-${esc(sound.name)}">
      <div class="sound-card-header">
        <span class="sound-name">${esc(sound.name)}</span>
        <span class="synth-type">${esc(sound.synth_type)}</span>
      </div>
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
loadBatches();
