require_relative "sample_library"

# Granular synthesis from a recorded sample.
# Uses Csound's `syncgrain` opcode to read tiny windowed slices of the
# sample at a controllable density, pitch, and read-rate.
module SynthGranularSample
  module_function

  MAX_SAMPLE_DURATION = 90.0 # seconds — GEN01 loads the whole file into RAM

  def generate(duration: nil, freq: nil)
    duration ||= rand(2.5..6.0).round(2)

    sample_path = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    sample_dur = SampleLibrary.duration_of(sample_path) || MAX_SAMPLE_DURATION

    # Pitch: full ratio (independent of grain read-rate). 1.0 = original pitch.
    pitch_semitones = rand(-12.0..12.0).round(2)
    pitch_ratio = (2.0 ** (pitch_semitones / 12.0)).round(5)

    # Grain size in seconds. Small = blurry cloud, large = recognisable fragments.
    grain_size = rand(0.02..0.20).round(4)

    # Pointer rate — how fast we read through the file.
    # 0 = freeze on a position, 1 = real-time, 0.25 = 4× stretch, 2 = 2× faster.
    pointer_rate = rand(0.0..1.5).round(3)

    # Grain density (grains per second). Higher = denser texture.
    grain_density = rand(20.0..120.0).round(1)

    amplitude = rand(0.4..0.7).round(2)

    attack = rand(0.1..0.8).round(3)
    release = rand(0.2..1.2).round(3)
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      sample: relative_sample_path(sample_path),
      sample_duration: sample_dur,
      pitch_semitones: pitch_semitones,
      grain_size: grain_size,
      pointer_rate: pointer_rate,
      grain_density: grain_density,
      amplitude: amplitude,
      envelope: { attack: attack, release: release }
    }

    csd = <<~CSD
      <CsoundSynthesizer>
      <CsOptions>
      -d
      </CsOptions>
      <CsInstruments>
      sr = 44100
      ksmps = 32
      nchnls = 2
      0dbfs = 1

      seed 0

      instr 1
        iamp = #{amplitude}
        ipitch = #{pitch_ratio}
        igrsize = #{grain_size}
        iprate = #{pointer_rate}
        igdens = #{grain_density}

        asnd syncgrain iamp, igdens, ipitch, igrsize, iprate, 1, 2, 100

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = asnd * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      ; GEN01: load source sample into table 1 (size 0 = use file's natural size)
      f 1 0 0 1 "#{sample_path}" 0 0 1
      ; Hanning window for grain envelope
      f 2 0 8192 20 2
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "granular_sample", duration: duration }
  end

  def relative_sample_path(path)
    return path unless SampleLibrary.samples_dir
    rel = path.sub(SampleLibrary.samples_dir + File::SEPARATOR, "")
    rel == path ? File.basename(path) : rel
  end
end
