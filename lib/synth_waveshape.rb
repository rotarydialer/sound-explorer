require_relative "param_override"

module SynthWaveshape
  module_function

  SOURCES = ["sine", "saw", "square", "triangle"].freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(1.5..4.0).round(2) }
    base_freq = ParamOverride.fetch(o, :base_freq) { freq || rand(80.0..600.0).round(2) }
    source = ParamOverride.fetch(o, :source) { SOURCES.sample }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.4..0.7).round(2) }

    drive_start = ParamOverride.fetch(o, :drive, :start) { rand(0.5..2.0).round(3) }
    drive_end = ParamOverride.fetch(o, :drive, :end) { rand(2.0..12.0).round(3) }
    post_gain = ParamOverride.fetch(o, :post_gain) { rand(0.4..0.8).round(3) }

    shape1 = ParamOverride.fetch(o, :shape, :shape1) { rand(0.0..0.8).round(3) }
    shape2 = ParamOverride.fetch(o, :shape, :shape2) { rand(0.0..0.8).round(3) }

    tone_cutoff = ParamOverride.fetch(o, :tone_cutoff) { rand(1500.0..6000.0).round(0) }

    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.01..0.2).round(3) }
    decay = ParamOverride.fetch(o, :envelope, :decay) { rand(0.05..0.4).round(3) }
    sustain = ParamOverride.fetch(o, :envelope, :sustain) { rand(0.4..0.9).round(2) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.1..0.6).round(3) }
    if attack + decay + release > duration * 0.9
      scale = (duration * 0.9) / (attack + decay + release)
      attack = (attack * scale).round(3)
      decay = (decay * scale).round(3)
      release = (release * scale).round(3)
    end

    source_line =
      case source
      when "sine"     then "asrc poscil 0.7, #{base_freq}"
      when "saw"      then "asrc vco2 0.7, #{base_freq}, 0"
      when "square"   then "asrc vco2 0.7, #{base_freq}, 10"
      when "triangle" then "asrc vco2 0.7, #{base_freq}, 12"
      end

    params = {
      source: source,
      base_freq: base_freq,
      amplitude: amplitude,
      drive: { start: drive_start, end: drive_end },
      post_gain: post_gain,
      shape: { shape1: shape1, shape2: shape2 },
      tone_cutoff: tone_cutoff,
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
        iamp = #{amplitude}

        #{source_line}

        kdrive line #{drive_start}, p3, #{drive_end}

        adist distort1 asrc, kdrive, #{post_gain}, #{shape1}, #{shape2}

        afilt tone adist, #{tone_cutoff}

        kenv madsr #{attack}, #{decay}, #{sustain}, #{release}
        aout = afilt * kenv * iamp

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "waveshape", duration: duration }
  end
end
