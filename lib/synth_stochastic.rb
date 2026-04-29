module SynthStochastic
  module_function

  def generate(duration: nil, freq: nil)
    duration ||= rand(3.0..7.0).round(2)
    center_freq = freq || rand(120.0..600.0).round(2)
    voice_count = rand(3..6)
    amplitude = rand(0.25..0.5).round(2)

    # Each voice has its own frequency offset and random-walk parameters
    voices = voice_count.times.map do |i|
      offset_ratio = rand(0.5..2.5).round(3)
      drift_amount = rand(2.0..40.0).round(2)   # Hz of drift around the offset
      drift_rate   = rand(0.3..3.0).round(3)    # Hz, frequency of randi updates
      {
        offset_ratio: offset_ratio,
        drift_amount: drift_amount,
        drift_rate: drift_rate,
        seed: i + 1
      }
    end

    flicker_rate = rand(2.0..15.0).round(2)
    flicker_depth = rand(0.2..0.5).round(3)

    # Slow overall envelope for swelling pad-like behaviour
    attack = rand(0.5..2.0).round(3)
    release = rand(0.8..2.5).round(3)
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      center_freq: center_freq,
      voice_count: voice_count,
      voices: voices,
      flicker: { rate: flicker_rate, depth: flicker_depth },
      amplitude: amplitude,
      envelope: { attack: attack, release: release }
    }

    voice_amp = (amplitude / voice_count).round(5)

    voice_lines = voices.map.with_index do |v, i|
      base = (center_freq * v[:offset_ratio]).round(3)
      [
        "  kdrift#{i} randi #{v[:drift_amount]}, #{v[:drift_rate]}, #{v[:seed]}",
        "  a#{i} poscil #{voice_amp}, #{base} + kdrift#{i}"
      ].join("\n")
    end

    sum_expr = (0...voice_count).map { |i| "a#{i}" }.join(" + ")

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
      #{voice_lines.join("\n")}

        ; Random amplitude flicker over the whole sound
        kflick randi #{flicker_depth}, #{flicker_rate}, #{voice_count + 1}
        kflickenv = 1 - #{flicker_depth} + kflick

        amix = (#{sum_expr}) * kflickenv

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = amix * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "stochastic", duration: duration }
  end
end
