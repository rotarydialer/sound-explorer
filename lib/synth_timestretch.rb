require_relative "sample_library"

# Phase-vocoder time-stretch and pitch-shift of a sample, decoupled.
# Uses `mincer` — single opcode, streams from a function table.
module SynthTimestretch
  module_function

  # mincer needs the sample loaded into a function table. We cap to keep
  # memory reasonable; longer files can still be used but only a window
  # of them will be read during playback.
  MAX_SAMPLE_DURATION = 180.0

  def generate(duration: nil, freq: nil)
    duration ||= rand(2.0..5.0).round(2)

    sample_path = SampleLibrary.pick(max_duration: MAX_SAMPLE_DURATION)
    sample_dur = SampleLibrary.duration_of(sample_path) || MAX_SAMPLE_DURATION

    # Stretch factor: how much slower (>1) or faster (<1) than original.
    stretch = rand(0.25..4.0).round(3)

    # Pitch shift in semitones, independent of stretch.
    pitch_semitones = rand(-12.0..12.0).round(2)
    pitch_ratio = (2.0 ** (pitch_semitones / 12.0)).round(5)

    # How much of the file to traverse during playback. With stretch=2 and
    # p3=4s, we read p3/stretch = 2s of source material.
    source_window = (duration / stretch).round(3)

    # Pick a start position that keeps the read inside the file.
    max_start = [sample_dur - source_window, 0.0].max
    start_pos = max_start > 0 ? rand(0.0..max_start).round(3) : 0.0
    end_pos = (start_pos + source_window).round(3)

    # Lock formants: 1 keeps formant freqs fixed when pitch-shifting (voice-like).
    lock_formants = rand < 0.4 ? 1 : 0

    amplitude = rand(0.5..0.8).round(2)

    attack = rand(0.05..0.3).round(3)
    release = rand(0.1..0.4).round(3)
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

        ; Time pointer: walk from start_pos to end_pos over the playback duration.
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
