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
--count N          Number of sounds to generate (default: 10)
--types LIST       Comma-separated synthesis types (default: all)
--duration SECS    Fix duration for all sounds (default: random per sound)
```

**Examples:**

```bash
# Generate 20 sounds
ruby generate.rb --count 20

# Only FM and subtractive synthesis
ruby generate.rb --types fm,subtractive

# Short sounds for quick testing
ruby generate.rb --count 4 --duration 1.5
```

### Synthesis types

| Type | Flag | Description |
|------|------|-------------|
| FM | `fm` | Frequency modulation — carrier + modulator oscillator. Produces metallic, bell-like, and complex timbres. |
| Subtractive | `subtractive` | Band-limited oscillator (sawtooth, square, or triangle) through a resonant Moog ladder filter with envelope-modulated cutoff. |
| Additive | `additive` | Sum of harmonically-related partials with randomized amplitudes and slight detuning. |
| Granular | `granular` | Overlapping grain streams with randomized pitch scatter, grain density, and duration. |

### Output structure

Each run creates a timestamped batch directory:

```
output/
  2026-04-08_143022/
    fm_001.wav           # Full-quality audio (44100 Hz, 16-bit)
    fm_001.ogg           # Compressed for web playback
    fm_001.json          # Metadata (see below)
    subtractive_001.wav
    subtractive_001.ogg
    subtractive_001.json
    ...
```

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
