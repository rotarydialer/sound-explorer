require_relative "param_override"

module SynthKarplus
  module_function

  METHODS = {
    1 => "simple_average",
    2 => "stretched_average",
    6 => "all_pass"
  }.freeze
  METHOD_CODES = METHODS.invert.freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.0..3.5).round(2) }
    base_freq = ParamOverride.fetch(o, :base_freq) { freq || rand(80.0..1200.0).round(2) }
    method_name = ParamOverride.fetch(o, :method) { METHODS[METHODS.keys.sample] }
    method = METHOD_CODES.fetch(method_name, 1)
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.4..0.8).round(2) }
    voice_count = ParamOverride.fetch(o, :voices) { rand(1..3) }

    detunes = ParamOverride.fetch(o, :detunes_cents) do
      ds = voice_count.times.map { rand(-12.0..12.0).round(2) }
      ds[0] = 0.0 if ds.any?
      ds
    end
    voice_count = detunes.size if detunes.size != voice_count

    iparm1 = ParamOverride.fetch(o, :iparm1) do
      case method
      when 2 then rand(1.0..6.0).round(3)
      when 6 then rand(-0.5..0.5).round(3)
      else 1
      end
    end

    release = ParamOverride.fetch(o, :release) { [rand(0.05..0.3).round(3), duration * 0.4].min }

    params = {
      base_freq: base_freq,
      method: METHODS[method],
      amplitude: amplitude,
      voices: voice_count,
      detunes_cents: detunes,
      release: release,
      iparm1: iparm1
    }

    voice_lines = detunes.map.with_index do |cents, i|
      ratio = (2.0 ** (cents / 1200.0)).round(6)
      vfreq = (base_freq * ratio).round(4)
      "  a#{i} pluck #{(amplitude / voice_count).round(5)}, #{vfreq}, #{vfreq}, 0, #{method}, #{iparm1}"
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

        amix = #{sum_expr}

        aenv linseg 1, p3 - #{release}, 1, #{release}, 0
        aout = amix * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "karplus", duration: duration }
  end
end
