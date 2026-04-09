module SynthAdditive
  module_function

  def generate(duration: nil)
    duration ||= rand(1.0..4.0).round(2)
    fundamental = rand(80.0..600.0).round(2)
    num_partials = rand(3..16)
    amplitude = rand(0.3..0.7).round(2)

    # Generate partial amplitudes with a randomized rolloff curve
    rolloff_exp = rand(0.5..2.5).round(3)
    partials = (1..num_partials).map do |n|
      amp = (1.0 / (n ** rolloff_exp)).round(4)
      detune = rand(-5.0..5.0).round(3) # cents of detuning per partial
      { harmonic: n, amplitude: amp, detune_cents: detune }
    end

    # Envelope
    attack = rand(0.05..1.0).round(3)
    decay = rand(0.05..0.5).round(3)
    sustain = rand(0.3..0.9).round(2)
    release = rand(0.2..1.5).round(3)

    env_total = attack + decay + release
    if env_total > duration * 0.9
      scale = (duration * 0.9) / env_total
      attack = (attack * scale).round(3)
      decay = (decay * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      fundamental: fundamental,
      num_partials: num_partials,
      rolloff_exponent: rolloff_exp,
      amplitude: amplitude,
      partials: partials,
      envelope: { attack: attack, decay: decay, sustain: sustain, release: release }
    }

    # Build the oscillator lines for each partial
    osc_lines = partials.map.with_index do |p, i|
      detune_ratio = 2.0 ** (p[:detune_cents] / 1200.0)
      freq = "ifund * #{p[:harmonic]} * #{detune_ratio.round(6)}"
      "  a#{i} poscil #{(amplitude * p[:amplitude]).round(5)}, #{freq}"
    end

    sum_expr = (0...partials.size).map { |i| "a#{i}" }.join(" + ")

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
        ifund = #{fundamental}

        ; Partials
      #{osc_lines.join("\n")}

        amix = #{sum_expr}

        ; Amplitude envelope
        aenv madsr #{attack}, #{decay}, #{sustain}, #{release}
        aout = amix * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "additive", duration: duration }
  end
end
