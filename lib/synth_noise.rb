require_relative "param_override"

module SynthNoise
  module_function

  COLORS = ["white", "pink"].freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(2.0..6.0).round(2) }
    color = ParamOverride.fetch(o, :color) { COLORS.sample }

    start_cut = ParamOverride.fetch(o, :cutoff_start) { freq || rand(200.0..3000.0).round(2) }
    sweep_octaves = ParamOverride.fetch(o, :sweep_octaves) { rand(-2.0..2.0).round(2) }
    end_cut = ParamOverride.fetch(o, :cutoff_end) { (start_cut * (2.0 ** sweep_octaves)).round(2).clamp(60.0, 12000.0) }

    bandwidth = ParamOverride.fetch(o, :bandwidth) { rand(50.0..600.0).round(1) }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.3..0.6).round(2) }
    filter_type = ParamOverride.fetch(o, :filter) { ["butterbp", "resonz"].sample }
    gain_comp = ParamOverride.fetch(o, :gain_compensation) do
      filter_type == "butterbp" ? rand(6.0..14.0).round(2) : rand(2.0..5.0).round(2)
    end

    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.2..1.5).round(3) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.3..2.0).round(3) }
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    noise_op = color == "white" ? "rand 1" : "pinkish 1"

    params = {
      color: color,
      filter: filter_type,
      cutoff_start: start_cut,
      cutoff_end: end_cut,
      sweep_octaves: sweep_octaves,
      bandwidth: bandwidth,
      gain_compensation: gain_comp,
      amplitude: amplitude,
      envelope: { attack: attack, release: release }
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

      seed 0

      instr 1
        iamp = #{amplitude}

        anoise #{noise_op}

        kcut expseg #{start_cut}, p3, #{end_cut}

        afilt #{filter_type} anoise, kcut, #{bandwidth}
        afilt = afilt * #{gain_comp}

        aenv linseg 0, #{attack}, 1, p3 - #{attack} - #{release}, 1, #{release}, 0
        aout = afilt * aenv * iamp

        aout clip aout, 0, 0.95

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "noise", duration: duration }
  end
end
