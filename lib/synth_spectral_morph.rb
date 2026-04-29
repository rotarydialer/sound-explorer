require_relative "sample_library"

# Spectral morph: smoothly interpolate between the spectral frames of two
# samples. Uses `pvstanal` (table-driven streaming phase-vocoder analysis)
# into `pvsmorph` and resynthesises with `pvsynth`.
module SynthSpectralMorph
  module_function

  MAX_SAMPLE_DURATION = 15.0

  MORPH_SHAPES = ["linear", "reverse", "sine", "random_walk"].freeze

  def generate(duration: nil, freq: nil)
    duration ||= rand(3.0..7.0).round(2)

    # Pick two distinct samples.
    sample_a = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    sample_b = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    8.times do
      break if sample_b != sample_a
      sample_b = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    end

    pitch_a_semis = rand(-7.0..7.0).round(2)
    pitch_b_semis = rand(-7.0..7.0).round(2)
    pitch_a = (2.0 ** (pitch_a_semis / 12.0)).round(5)
    pitch_b = (2.0 ** (pitch_b_semis / 12.0)).round(5)

    morph_shape = MORPH_SHAPES.sample
    morph_rate = rand(0.05..0.5).round(3) # Hz, slow oscillation

    amplitude = rand(0.4..0.7).round(2)

    attack = rand(0.2..0.8).round(3)
    release = rand(0.3..1.2).round(3)
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      sample_a: relative_sample_path(sample_a),
      sample_b: relative_sample_path(sample_b),
      pitch_a_semitones: pitch_a_semis,
      pitch_b_semitones: pitch_b_semis,
      morph_shape: morph_shape,
      morph_rate: morph_rate,
      amplitude: amplitude,
      envelope: { attack: attack, release: release }
    }

    morph_signal =
      case morph_shape
      when "linear"
        "kmorph line 0, p3, 1"
      when "reverse"
        "kmorph line 1, p3, 0"
      when "sine"
        "kosc poscil 0.5, #{morph_rate}, 99\n  kmorph = kosc + 0.5"
      when "random_walk"
        "kmorph randi 0.5, #{morph_rate * 4}, 1\n  kmorph = kmorph + 0.5"
      end

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

        #{morph_signal}

        fsigA pvstanal 1, 1, #{pitch_a}, 1
        fsigB pvstanal 1, 1, #{pitch_b}, 2
        fmorph pvsmorph fsigA, fsigB, kmorph, kmorph

        aout pvsynth fmorph
        aout = aout * iamp

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = aout * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 0 1 "#{sample_a}" 0 0 1
      f 2 0 0 1 "#{sample_b}" 0 0 1
      f 99 0 4096 10 1
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "spectral_morph", duration: duration }
  end

  def relative_sample_path(path)
    return path unless SampleLibrary.samples_dir
    rel = path.sub(SampleLibrary.samples_dir + File::SEPARATOR, "")
    rel == path ? File.basename(path) : rel
  end
end
