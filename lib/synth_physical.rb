module SynthPhysical
  module_function

  # Three waveguide instruments from Csound's physical-modelling library.
  INSTRUMENTS = ["wgbow", "wgflute", "wgclar"].freeze

  def generate(duration: nil, freq: nil)
    duration ||= rand(1.5..4.5).round(2)
    base_freq = freq || rand(150.0..1000.0).round(2)
    instrument = INSTRUMENTS.sample
    amplitude = rand(0.3..0.6).round(2)

    # Vibrato common to all
    vib_freq = rand(4.0..7.0).round(2)
    vib_amp = rand(0.0..0.01).round(4)

    # Instrument-specific synthesis params
    instr_body, params_specific =
      case instrument
      when "wgbow"
        pres = rand(0.2..0.5).round(3)   # bow pressure
        rat  = rand(0.05..0.25).round(3) # relative bow position along string
        line = "abow wgbow #{amplitude}, kfreq, #{pres}, #{rat}, #{vib_freq}, #{vib_amp}, 1\n  aout = abow"
        [line, { bow_pressure: pres, bow_position: rat }]
      when "wgflute"
        jet = rand(0.2..0.6).round(3)
        ngain = rand(0.1..0.4).round(3)
        line = "aflute wgflute #{amplitude}, kfreq, #{jet}, 0.02, 0.02, #{ngain}, #{vib_freq}, #{vib_amp}, 1\n  aout = aflute"
        [line, { jet_ratio: jet, noise_gain: ngain }]
      when "wgclar"
        stiff = rand(-0.4..0.0).round(3) # reed stiffness
        ngain = rand(0.05..0.3).round(3)
        line = "aclar wgclar #{amplitude}, kfreq, #{stiff}, 0.02, 0.02, #{ngain}, #{vib_freq}, #{vib_amp}, 1\n  aout = aclar"
        [line, { reed_stiffness: stiff, noise_gain: ngain }]
      end

    attack = rand(0.05..0.4).round(3)
    release = rand(0.1..0.5).round(3)
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    # Slight pitch glide for expressivity
    glide_cents = rand(-30.0..30.0).round(2)
    end_freq = (base_freq * (2.0 ** (glide_cents / 1200.0))).round(3)

    params = {
      instrument: instrument,
      base_freq: base_freq,
      end_freq: end_freq,
      amplitude: amplitude,
      vibrato: { freq: vib_freq, amp: vib_amp },
      envelope: { attack: attack, release: release },
      glide_cents: glide_cents
    }.merge(params_specific)

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
        kfreq line #{base_freq}, p3, #{end_freq}

        #{instr_body}

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = aout * aenv

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 4096 10 1
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "physical", duration: duration }
  end
end
