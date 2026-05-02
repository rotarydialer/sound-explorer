require_relative "sample_library"
require_relative "param_override"

module SynthTimestretch
  module_function

  MAX_SAMPLE_DURATION = 180.0

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(2.0..5.0).round(2) }

    sample_path =
      if (rel = ParamOverride.get(o, :sample)) && rel != ParamOverride::MISSING
        SampleLibrary.resolve(rel) || SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
      else
        SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
      end
    sample_dur = SampleLibrary.duration_of(sample_path) || MAX_SAMPLE_DURATION

    stretch = ParamOverride.fetch(o, :stretch) { rand(0.25..4.0).round(3) }
    pitch_semitones = ParamOverride.fetch(o, :pitch_semitones) { rand(-12.0..12.0).round(2) }
    pitch_ratio = (2.0 ** (pitch_semitones / 12.0)).round(5)

    source_window = (duration / stretch).round(3)
    max_start = [sample_dur - source_window, 0.0].max
    start_pos = ParamOverride.fetch(o, :start_position) { max_start > 0 ? rand(0.0..max_start).round(3) : 0.0 }
    end_pos = ParamOverride.fetch(o, :end_position) { (start_pos + source_window).round(3) }

    lock_formants = ParamOverride.fetch(o, :lock_formants) { rand < 0.4 ? 1 : 0 }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.5..0.8).round(2) }

    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.05..0.3).round(3) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.1..0.4).round(3) }
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      sample: relative_sample_path(sample_path),
      sample_duration: sample_dur,
      stretch: stretch,
      pitch_semitones: pitch_semitones,
      start_position: start_pos,
      end_position: end_pos,
      lock_formants: lock_formants,
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
        ipitch = #{pitch_ratio}

        atime line #{start_pos}, p3, #{end_pos}

        asnd mincer atime, iamp, ipitch, 1, #{lock_formants}

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = asnd * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 0 1 "#{sample_path}" 0 0 1
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "timestretch", duration: duration }
  end

  def relative_sample_path(path)
    return path unless SampleLibrary.samples_dir
    rel = path.sub(SampleLibrary.samples_dir + File::SEPARATOR, "")
    rel == path ? File.basename(path) : rel
  end
end
