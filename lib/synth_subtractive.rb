module SynthSubtractive
  module_function

  def generate(duration: nil)
    duration ||= rand(1.0..4.0).round(2)
    base_freq = rand(60.0..800.0).round(2)
    # vco2 waveform type: 0=sawtooth, 10=square, 12=triangle
    waveform = [0, 10, 12].sample
    waveform_name = { 0 => "sawtooth", 10 => "square", 12 => "triangle" }[waveform]
    detune_cents = rand(-15.0..15.0).round(2)
    amplitude = rand(0.3..0.7).round(2)

    # Filter params
    filter_cutoff_mult = rand(2.0..12.0).round(2)
    filter_resonance = rand(0.05..0.7).round(3)
    filter_env_amount = rand(1.0..6.0).round(2)

    # Envelopes
    amp_attack = rand(0.01..0.4).round(3)
    amp_decay = rand(0.05..0.4).round(3)
    amp_sustain = rand(0.2..0.8).round(2)
    amp_release = rand(0.1..0.8).round(3)

    filt_attack = rand(0.01..0.3).round(3)
    filt_decay = rand(0.1..0.6).round(3)
    filt_sustain = rand(0.1..0.5).round(2)
    filt_release = rand(0.1..0.5).round(3)

    # Clamp envelopes
    [amp_attack + amp_decay + amp_release, filt_attack + filt_decay + filt_release].each_with_index do |total, i|
      if total > duration * 0.9
        scale = (duration * 0.9) / total
        if i == 0
          amp_attack = (amp_attack * scale).round(3)
          amp_decay = (amp_decay * scale).round(3)
          amp_release = (amp_release * scale).round(3)
        else
          filt_attack = (filt_attack * scale).round(3)
          filt_decay = (filt_decay * scale).round(3)
          filt_release = (filt_release * scale).round(3)
        end
      end
    end

    params = {
      base_freq: base_freq,
      waveform: waveform_name,
      detune_cents: detune_cents,
      amplitude: amplitude,
      filter: {
        cutoff_multiplier: filter_cutoff_mult,
        resonance: filter_resonance,
        env_amount: filter_env_amount
      },
      amp_envelope: { attack: amp_attack, decay: amp_decay, sustain: amp_sustain, release: amp_release },
      filter_envelope: { attack: filt_attack, decay: filt_decay, sustain: filt_sustain, release: filt_release }
    }

    # Detune factor: convert cents to ratio
    detune_ratio = 2.0 ** (detune_cents / 1200.0)

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
        ifreq = #{base_freq}
        iamp = #{amplitude} * 0.5
        ifreq2 = ifreq * #{detune_ratio.round(6)}

        ; Two oscillators with detuning
        aosc1 vco2 iamp, ifreq, #{waveform}
        aosc2 vco2 iamp, ifreq2, #{waveform}
        amix = aosc1 + aosc2

        ; Filter envelope
        kfenv madsr #{filt_attack}, #{filt_decay}, #{filt_sustain}, #{filt_release}

        ; Dynamic filter cutoff
        ibase_cut = ifreq * #{filter_cutoff_mult}
        ienv_range = ifreq * #{filter_env_amount}
        kcutoff = ibase_cut + (kfenv * ienv_range)

        ; Moog ladder filter
        afilt moogladder amix, kcutoff, #{filter_resonance}

        ; Amplitude envelope
        kaenv madsr #{amp_attack}, #{amp_decay}, #{amp_sustain}, #{amp_release}
        aout = afilt * kaenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "subtractive", duration: duration }
  end
end
