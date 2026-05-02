require_relative "param_override"

module SynthFormant
  module_function

  VOWELS = {
    "a" => [[650, 80], [1080, 90], [2650, 120]],
    "e" => [[400, 70], [1700, 80], [2600, 100]],
    "i" => [[290, 50], [1870, 100], [2800, 120]],
    "o" => [[400, 40], [800,  80], [2600, 100]],
    "u" => [[350, 40], [600,  80], [2700, 100]]
  }.freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.5..4.0).round(2) }
    fundamental = ParamOverride.fetch(o, :fundamental) { freq || rand(80.0..300.0).round(2) }
    vowel = ParamOverride.fetch(o, :vowel) { VOWELS.keys.sample }
    default_formants = VOWELS[vowel] || VOWELS.values.first
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.25..0.5).round(2) }

    vib_rate = ParamOverride.fetch(o, :vibrato, :rate) { rand(4.0..7.0).round(2) }
    vib_depth = ParamOverride.fetch(o, :vibrato, :depth) { rand(0.0..0.015).round(4) }

    glide_cents = ParamOverride.fetch(o, :glide_cents) { rand(-100.0..100.0).round(2) }
    end_freq = ParamOverride.fetch(o, :end_freq) { (fundamental * (2.0 ** (glide_cents / 1200.0))).round(3) }

    formants_list = ParamOverride.fetch(o, :formants) do
      f_amps = [1.0, rand(0.4..0.7).round(3), rand(0.2..0.5).round(3)]
      default_formants.map.with_index { |(f, bw), i| { freq: f, bandwidth: bw, amplitude: f_amps[i] } }
    end
    formants_list = formants_list.map do |fm|
      {
        freq: fm[:freq] || fm["freq"],
        bandwidth: fm[:bandwidth] || fm["bandwidth"],
        amplitude: fm[:amplitude] || fm["amplitude"]
      }
    end

    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.05..0.3).round(3) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.15..0.5).round(3) }
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      fundamental: fundamental,
      end_freq: end_freq,
      vowel: vowel,
      amplitude: amplitude,
      formants: formants_list,
      vibrato: { rate: vib_rate, depth: vib_depth },
      envelope: { attack: attack, release: release }
    }

    fof_lines = formants_list.each_with_index.map do |fm, i|
      a = (amplitude * fm[:amplitude]).round(5)
      "  af#{i} fof2 #{a}, kfund, #{fm[:freq]}, 0, #{fm[:bandwidth]}, 0.003, 0.017, 0.007, 100, 1, 2, p3, 0, 0"
    end

    mix_expr = (0...formants_list.size).map { |i| "af#{i}" }.join(" + ")

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
        kgliss line #{fundamental}, p3, #{end_freq}
        kvib poscil #{vib_depth}, #{vib_rate}
        kfund = kgliss * (1 + kvib)

      #{fof_lines.join("\n")}

        amix = #{mix_expr}

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = amix * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 8192 10 1
      f 2 0 1024 19 0.5 0.5 270 0.5
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "formant", duration: duration }
  end
end
