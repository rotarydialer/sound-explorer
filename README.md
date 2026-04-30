# Sound Explorer

A local tool for generating and exploring synthesized sounds. Sounds are created using [Csound](https://csound.com/) with randomized parameters, recorded with full metadata for reproducibility, and browsable via a web interface.

## Requirements

- Ruby (stdlib only — no gems required for phases 1–2)
- [Csound](https://csound.com/) 6.x
- [ffmpeg](https://ffmpeg.org/) (for OGG conversion)

## Phase 1 & 2: Sound Generation

### Basic usage

```bash
ruby generate.rb
```

Generates 10 sounds (2–3 of each synthesis type) into a timestamped batch directory under `output/`.

### Options

```
--count N           Number of sounds to generate (default: 10)
--types LIST        Comma-separated synthesis types (default: all)
--duration SECS     Fix duration for all sounds (default: random per sound)
--freq HZ           Fix base frequency for all sounds (default: random per sound)
--formats LIST      Comma-separated output formats: ogg,wav (default: ogg)
--samples-dir PATH  Directory containing audio samples for sample-based synths
                    (default: $SAMPLES_DIR or ./samples)
--samples-info      Print info about the configured sample library and exit
```

**Examples:**

```bash
# Generate 20 sounds
ruby generate.rb --count 20

# Only FM and subtractive synthesis
ruby generate.rb --types fm,subtractive

# Short sounds for quick testing
ruby generate.rb --count 4 --duration 1.5

# Keep both WAV and OGG
ruby generate.rb --formats wav,ogg
```

### Synthesis types

#### Pure synthesis

| Type | Flag | Description |
|------|------|-------------|
| FM | `fm` | Frequency modulation — carrier + modulator oscillator. Produces metallic, bell-like, and complex timbres. |
| Subtractive | `subtractive` | Band-limited oscillator (sawtooth, square, or triangle) through a resonant Moog ladder filter with envelope-modulated cutoff. |
| Additive | `additive` | Sum of harmonically-related partials with randomized amplitudes and slight detuning. |
| Granular | `granular` | Overlapping grain streams with randomized pitch scatter, grain density, and duration. |
| Karplus | `karplus` | Karplus-Strong plucked-string synthesis (Csound `pluck`). 1–3 voices with detuning. |
| Modal | `modal` | Sum of decaying resonant modes (Csound `mode`) excited by a brief noise burst. Bell, marimba, tubular, metal-bar, and wood-block presets. |
| Drum | `drum` | Pitched body with rapid pitch sweep + filtered noise click. Kick / snare / tom / hat / perc archetypes. |
| Physical | `physical` | Waveguide physical models (`wgbow`, `wgflute`, `wgclar`). Bowed string, blown flute, reed clarinet. |
| Formant | `formant` | Vocal-formant synthesis using `fof2` granular pulses tuned to vowel formants (a, e, i, o, u). |
| Noise | `noise` | White or pink noise through a band-pass filter (`butterbp` or `resonz`) with a swept centre frequency. |
| Stochastic | `stochastic` | Multiple voices with random pitch drift and amplitude flicker — drifting glitchy pads. |
| Waveshape | `waveshape` | Sine/saw/square/triangle source through `distort1` waveshaper with sweeping drive and a tone-control low-pass. |
| Ring mod | `ringmod` | Two oscillators multiplied (carrier × modulator). Inharmonic ratios → metallic, bell-metallic timbres. |

#### Sample-based

These require a sample library (see [Sample library](#sample-library) below).

| Type | Flag | Description |
|------|------|-------------|
| Granular (sample) | `granular_sample` | `syncgrain`-based granular synthesis from a recorded sample, with independent control over pitch, grain size, density, and read-rate. |
| Time stretch | `timestretch` | Phase-vocoder time-stretch + pitch-shift via `mincer` — stretch and pitch are decoupled. |
| Spectral morph | `spectral_morph` | Two samples spectrally interpolated with `pvsmorph`. Morph curve can be linear, reverse, sine, or random walk. |
| Cross synthesis | `cross_synth` | Vocoder-like `pvscross`: spectral envelope of one sample imposed on the harmonic content of another. |
| Convolution | `convolution` | Synthesised excitation (pluck / noise burst / tone) convolved with a sample acting as an impulse response, via `ftconv`. |

### Sample library

The sample-based synthesis types (`granular_sample`, `timestretch`,
`spectral_morph`, `cross_synth`, `convolution`) read from a directory of
audio files that you supply. The library is **not** checked into git —
point the tool at any directory you already have.

#### Configuring

Three ways to set the samples directory, in order of precedence:

1. `--samples-dir PATH` flag
2. `SAMPLES_DIR` environment variable
3. `./samples/` (relative to the repo root) by default

```bash
# Point at an external library
ruby generate.rb --samples-dir /mnt/audio/my-samples --types granular_sample

# Or set once for the shell session
export SAMPLES_DIR=/mnt/audio/my-samples
ruby generate.rb --types timestretch,spectral_morph

# Inspect what was found
ruby generate.rb --samples-dir /mnt/audio/my-samples --samples-info
```

#### Format and structure

- Supported formats: **WAV, AIFF, FLAC** (Csound + libsndfile native support).
- The directory is scanned **recursively**; subdirectories are optional.
- If the top level contains subdirectories, their names become **categories**
  (e.g. `samples/percussive/`, `samples/tonal/`, `samples/ir/`). Modules can
  filter by category if they want to. Flat directories also work.

#### Length-aware routing

Each sample-based module has a maximum duration it will accept, because
several techniques load the whole file into a function table in RAM. The
caps:

| Module | Max sample length |
|---|---|
| `timestretch` | 180 s |
| `granular_sample` | 90 s |
| `spectral_morph` | 45 s |
| `cross_synth` | 45 s |
| `convolution` (IR) | 10 s |

Longer files in your library are simply skipped by modules with stricter
caps. Durations are probed lazily with `ffprobe` and cached in
`<samples-dir>/.sample_durations.json` so each file is only probed once
across all runs.

At the start of each batch that uses sample-based types, `generate.rb`
prints a per-module pool size so you can see how many samples each module
has to draw from:

```
Sample library: 4 files in /tmp/test_samples
  granular_sample  4/4 samples ≤ 90.0s (100%)
  timestretch      4/4 samples ≤ 180.0s (100%)
  spectral_morph   3/4 samples ≤ 45.0s (75%)  ⚠ pool is small — bias likely
  cross_synth      3/4 samples ≤ 45.0s (75%)  ⚠ pool is small — bias likely
  convolution      2/4 samples ≤ 10.0s (50%)  ⚠ pool is small — bias likely
```

Pools under 4 samples get a "bias likely" warning — repeated picks will
visibly cluster around the few survivors. If you see this, either add
shorter samples to the library or trim long ones with ffmpeg.

#### Practical tips

- Curate a working subset (a few GB max) by copying or symlinking a slice
  of your full library into a dedicated directory and pointing
  `--samples-dir` at it. The system handles tens of thousands of files
  fine, but cold-probing them all on first use takes a moment.
- Add a `samples/ir/` subdirectory of short, percussive hits or real
  impulse responses for `convolution` to draw on (it picks any sample ≤ 5 s
  by default, but a curated set produces more musical results).

### Output structure

Each run creates a timestamped batch directory:

```
output/
  2026-04-08_143022/
    fm_001.ogg           # Audio (OGG Vorbis)
    fm_001.json          # Metadata (see below)
    subtractive_001.ogg
    subtractive_001.json
    ...
```

With `--formats wav,ogg`, both formats are kept. With `--formats wav`, only WAV is produced (no ffmpeg conversion).

### Metadata format

Every sound has a companion `.json` file:

```json
{
  "name": "fm_001",
  "synth_type": "fm",
  "batch": "2026-04-08_143022",
  "created_at": "2026-04-08T14:30:25Z",
  "duration_seconds": 2.86,
  "sample_rate": 44100,
  "params": {
    "carrier_freq": 440.0,
    "mod_ratio": 2.01,
    "mod_index": 5.3,
    "amplitude": 0.7,
    "envelope": {
      "attack": 0.05,
      "decay": 0.2,
      "sustain": 0.6,
      "release": 0.4
    }
  },
  "csd_content": "...",
  "files": {
    "wav": "fm_001.wav",
    "ogg": "fm_001.ogg"
  },
  "tags": [],
  "description": ""
}
```

- **`params`** — all randomized values used to generate this sound
- **`csd_content`** — the complete Csound `.csd` file; paste into a `.csd` file and run with `csound` to reproduce the sound exactly
- **`tags` / `description`** — populated by the AI tagging phase (phase 4)

### Regenerating a sound

To reproduce any sound exactly, extract the `csd_content` field and run it through csound:

```bash
# Extract and render (requires jq)
cat output/2026-04-08_143022/fm_001.json | jq -r .csd_content > repro.csd
csound -W -d -o repro.wav repro.csd
```

Or copy the `csd_content` value from the JSON into a `.csd` file manually.

### Playing sounds

```bash
# With ffplay (comes with ffmpeg)
ffplay output/2026-04-08_143022/fm_001.wav

# Or open the OGG in any audio player
```
