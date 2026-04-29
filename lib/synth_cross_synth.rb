require_relative "sample_library"

# Spectral cross-synthesis: takes the amplitude envelope (formant shape) of
# one sample and applies it to the spectral content of another. Vocoder-like
# results — speech rhythms on a drone, drum transients on a string pad.
module SynthCrossSynth
  module_function

  MAX_SAMPLE_DURATION = 15.0

  def generate(duration: nil, freq: nil)
    duration ||= rand(3.0..6.0).round(2)

    # "Excitor" provides the harmonic/pitched content; "filter" provides the
    # spectral shape that gets imposed.
    excitor = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    filter_src = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    8.times do
      break if filter_src != excitor
      filter_src = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    end

    excitor_pitch_semis = rand(-7.0..7.0).round(2)
    filter_pitch_semis = rand(-3.0..3.0).round(2)
    excitor_pitch = (2.0 ** (excitor_pitch_semis / 12.0)).round(5)
    filter_pitch = (2.0 ** (filter_pitch_semis / 12.0)).round(5)

    # Cross-synthesis amount mixes excitor's amps (kamp1) with filter's amps (kamp2).
    cross_amount = rand(0.4..1.0).round(3)
    excitor_amp = (1.0 - cross_amount).round(3)

    amplitude = rand(0.4..0.7).round(2)

    attack = rand(0.1..0.5).round(3)
    release = rand(0.2..0.8).round(3)
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      excitor_sample: relative_sample_path(excitor),
      filter_sample: relative_sample_path(filter_src),
      excitor_pitch_semitones: excitor_pitch_semis,
      filter_pitch_semitones: filter_pitch_semis,
      cross_amount: cross_amount,
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

      instr 1
        iamp = #{amplitude}

        fsigE pvstanal 1, 1, #{excitor_pitch}, 1
        fsigF pvstanal 1, 1, #{filter_pitch}, 2

        ; pvscross: amplitudes from F, frequencies from E.
        fcross pvscross fsigE, fsigF, #{excitor_amp}, #{cross_amount}
        aout pvsynth fcross

        aout = aout * iamp

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = aout * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 0 1 "#{excitor}" 0 0 1
      f 2 0 0 1 "#{filter_src}" 0 0 1
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "cross_synth", duration: duration }
  end

  def relative_sample_path(path)
    return path unless SampleLibrary.samples_dir
    rel = path.sub(SampleLibrary.samples_dir + File::SEPARATOR, "")
    rel == path ? File.basename(path) : rel
  end
end
