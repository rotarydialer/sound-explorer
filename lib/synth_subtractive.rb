require_relative "param_override"

module SynthSubtractive
  module_function

  WAVEFORM_NAMES = { 0 => "sawtooth", 10 => "square", 12 => "triangle" }.freeze
  WAVEFORM_CODES = WAVEFORM_NAMES.invert.freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.0..4.0).round(2) }
    base_freq = ParamOverride.fetch(o, :base_freq) { freq || rand(60.0..800.0).round(2) }
    waveform_name = ParamOverride.fetch(o, :waveform) { [0, 10, 12].sample.then { |c| WAVEFORM_NAMES[c] } }
    waveform = WAVEFORM_CODES.fetch(waveform_name, 0)
    detune_cents = ParamOverride.fetch(o, :detune_cents) { rand(-15.0..15.0).round(2) }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.3..0.7).round(2) }

    filter_cutoff_mult = ParamOverride.fetch(o, :filter, :cutoff_multiplier) { rand(2.0..12.0).round(2) }
    filter_resonance = ParamOverride.fetch(o, :filter, :resonance) { rand(0.05..0.7).round(3) }
    filter_env_amount = ParamOverride.fetch(o, :filter, :env_amount) { rand(1.0..6.0).round(2) }

    amp_attack = ParamOverride.fetch(o, :amp_envelope, :attack) { rand(0.01..0.4).round(3) }
    amp_decay = ParamOverride.fetch(o, :amp_envelope, :decay) { rand(0.05..0.4).round(3) }
    amp_sustain = ParamOverride.fetch(o, :amp_envelope, :sustain) { rand(0.2..0.8).round(2) }
    amp_release = ParamOverride.fetch(o, :amp_envelope, :release) { rand(0.1..0.8).round(3) }

    filt_attack = ParamOverride.fetch(o, :filter_envelope, :attack) { rand(0.01..0.3).round(3) }
    filt_decay = ParamOverride.fetch(o, :filter_envelope, :decay) { rand(0.1..0.6).round(3) }
    filt_sustain = ParamOverride.fetch(o, :filter_envelope, :sustain) { rand(0.1..0.5).round(2) }
    filt_release = ParamOverride.fetch(o, :filter_envelope, :release) { rand(0.1..0.5).round(3) }

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
