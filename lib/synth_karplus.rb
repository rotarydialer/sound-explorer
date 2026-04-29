module SynthKarplus
  module_function

  # Methods for the pluck opcode:
  # 1 = simple averaging, 2 = stretched averaging, 6 = 1st order all-pass.
  # 3/4 are drum-like and live in synth_drum / synth_modal instead.
  METHODS = {
    1 => "simple_average",
    2 => "stretched_average",
    6 => "all_pass"
  }.freeze

  def generate(duration: nil, freq: nil)
    duration ||= rand(1.0..3.5).round(2)
    base_freq = freq || rand(80.0..1200.0).round(2)
    method = METHODS.keys.sample
    amplitude = rand(0.4..0.8).round(2)

    # Layer 1-3 plucks at slight detunings for chorus-like richness.
    voice_count = rand(1..3)
    detunes = voice_count.times.map { rand(-12.0..12.0).round(2) } # cents
    detunes[0] = 0.0 # primary voice in tune

    # Method-specific iparm1:
    #   1 = simple averaging  → iparm1 unused (default 1.0)
    #   2 = stretched average → iparm1 is stretch factor, must be ≥ 1
    #   6 = 1st-order all-pass → iparm1 is all-pass coefficient, range -1..1
    iparm1 = case method
             when 2 then rand(1.0..6.0).round(3)
             when 6 then rand(-0.5..0.5).round(3)
             else 1
             end

    # Soft tail to prevent abrupt cutoff
    release = [rand(0.05..0.3).round(3), duration * 0.4].min

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

        ; Soft tail so the buffer's natural decay doesn't click off
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
