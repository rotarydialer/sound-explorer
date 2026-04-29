module SynthRingmod
  module_function

  CARRIER_WAVES = ["sine", "saw", "triangle"].freeze

  def generate(duration: nil, freq: nil)
    duration ||= rand(1.5..4.0).round(2)
    carrier_freq = freq || rand(100.0..1200.0).round(2)

    # Modulator frequency: a non-harmonic ratio of the carrier produces the
    # classic metallic, inharmonic ring-mod timbre.
    mod_ratio = [
      rand(0.21..0.79),     # below carrier
      rand(1.13..2.87),     # between 1× and 3×
      rand(3.01..7.21)      # high inharmonic
    ].sample.round(4)
    mod_freq = (carrier_freq * mod_ratio).round(3)

    carrier_wave = CARRIER_WAVES.sample
    amplitude = rand(0.4..0.7).round(2)

    # Mix between dry carrier and ring product. 1.0 = full ring mod, 0 = dry.
    ring_amount = rand(0.5..1.0).round(3)

    # LFO modulating the modulator pitch slowly for movement
    sweep_octaves = rand(-1.0..1.0).round(2)
    mod_end = (mod_freq * (2.0 ** sweep_octaves)).round(3)

    attack = rand(0.01..0.4).round(3)
    decay = rand(0.05..0.4).round(3)
    sustain = rand(0.3..0.8).round(2)
    release = rand(0.1..0.7).round(3)
    if attack + decay + release > duration * 0.9
      scale = (duration * 0.9) / (attack + decay + release)
      attack = (attack * scale).round(3)
      decay = (decay * scale).round(3)
      release = (release * scale).round(3)
    end

    carrier_line =
      case carrier_wave
      when "sine"     then "acar poscil 1, #{carrier_freq}"
      when "saw"      then "acar vco2 1, #{carrier_freq}, 0"
      when "triangle" then "acar vco2 1, #{carrier_freq}, 12"
      end

    params = {
      carrier_freq: carrier_freq,
      carrier_wave: carrier_wave,
      mod_freq_start: mod_freq,
      mod_freq_end: mod_end,
      mod_ratio: mod_ratio,
      ring_amount: ring_amount,
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
        iamp = #{amplitude}

        kmodfreq line #{mod_freq}, p3, #{mod_end}
        amod poscil 1, kmodfreq

        #{carrier_line}

        aring = acar * amod
        amix = (aring * #{ring_amount}) + (acar * #{(1.0 - ring_amount).round(3)})

        kenv madsr #{attack}, #{decay}, #{sustain}, #{release}
        aout = amix * kenv * iamp * 0.5

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "ringmod", duration: duration }
  end
end
