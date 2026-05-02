require_relative "param_override"

module SynthModal
  module_function

  PRESETS = {
    "bell"       => [1.0, 2.756, 5.404, 8.933, 13.345],
    "marimba"    => [1.0, 3.932, 9.538, 16.688],
    "tubular"    => [1.0, 2.76, 5.40, 8.93],
    "metal_bar"  => [1.0, 2.0, 3.91, 6.46],
    "wood_block" => [1.0, 1.99, 3.41, 5.12]
  }.freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.5..4.0).round(2) }
    base_freq = ParamOverride.fetch(o, :base_freq) { freq || rand(120.0..1500.0).round(2) }
    preset_name = ParamOverride.fetch(o, :preset) { PRESETS.keys.sample }
    ratios = PRESETS[preset_name] || PRESETS.values.first
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.4..0.8).round(2) }

    modes = ParamOverride.fetch(o, :modes) do
      ratios.map.with_index do |ratio, i|
        q = (rand(800.0..3000.0) / (1 + i * 0.4)).round(1)
        amp = (1.0 / (1 + i * 0.6)).round(4)
        jitter = rand(-0.5..0.5).round(3)
        mode_freq = (base_freq * ratio + jitter).round(3)
        { freq: mode_freq, q: q, amplitude: amp }
      end
    end
    modes = modes.map { |m| { freq: m[:freq] || m["freq"], q: m[:q] || m["q"], amplitude: m[:amplitude] || m["amplitude"] } }

    excite_dur = ParamOverride.fetch(o, :excite_duration) { rand(0.001..0.008).round(4) }

    params = {
      base_freq: base_freq,
      preset: preset_name,
      amplitude: amplitude,
      excite_duration: excite_dur,
      modes: modes
    }

    mode_lines = modes.map.with_index do |m, i|
      "  am#{i} mode ain, #{m[:freq]}, #{m[:q]}"
    end

    mix_expr = modes.map.with_index { |m, i| "(am#{i} * #{m[:amplitude]})" }.join(" + ")

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

        aexcite linseg 1, #{excite_dur}, 1, 0.0001, 0, p3 - #{excite_dur} - 0.0001, 0
        anoise rand 1
        ain = anoise * aexcite

      #{mode_lines.join("\n")}

        amix = #{mix_expr}

        aenv linseg 1, p3 - 0.05, 1, 0.05, 0
        aout = amix * iamp * aenv * 0.3

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "modal", duration: duration }
  end
end
