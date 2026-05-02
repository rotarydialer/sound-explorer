require_relative "param_override"

module SynthFm
  module_function

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.0..4.0).round(2) }
    carrier_freq = ParamOverride.fetch(o, :carrier_freq) { freq || rand(100.0..2000.0).round(2) }
    mod_ratio = ParamOverride.fetch(o, :mod_ratio) { rand(0.5..8.0).round(3) }
    mod_index = ParamOverride.fetch(o, :mod_index) { rand(0.1..20.0).round(2) }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.3..0.8).round(2) }
    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.01..0.5).round(3) }
    decay = ParamOverride.fetch(o, :envelope, :decay) { rand(0.05..0.5).round(3) }
    sustain = ParamOverride.fetch(o, :envelope, :sustain) { rand(0.2..0.8).round(2) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.1..1.0).round(3) }

    # Clamp envelope so it fits within duration
    env_total = attack + decay + release
    if env_total > duration * 0.9
      scale = (duration * 0.9) / env_total
      attack = (attack * scale).round(3)
      decay = (decay * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      carrier_freq: carrier_freq,
      mod_ratio: mod_ratio,
      mod_index: mod_index,
      amplitude: amplitude,
      envelope: { attack: attack, decay: decay, sustain: sustain, release: release }
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
        icarr = #{carrier_freq}
        imod = icarr * #{mod_ratio}
        indx = #{mod_index}
        iamp = #{amplitude}

        aenv madsr #{attack}, #{decay}, #{sustain}, #{release}
        amod poscil indx * imod, imod
        acar poscil iamp * aenv, icarr + amod
        outs acar, acar
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "fm", duration: duration }
  end
end
