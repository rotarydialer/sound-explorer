require_relative "param_override"

module SynthGranular
  module_function

  GEN10_BY_WAVEFORM = {
    "sine"   => "1",
    "bright" => "1 0.5 0.3 0.2 0.1",
    "hollow" => "1 0 0.3 0 0.1"
  }.freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    duration = ParamOverride.fetch(o, :duration) { duration || rand(2.0..6.0).round(2) }
    base_freq = ParamOverride.fetch(o, :base_freq) { freq || rand(100.0..800.0).round(2) }
    grain_density = ParamOverride.fetch(o, :grain_density) { rand(5.0..80.0).round(1) }
    grain_dur = ParamOverride.fetch(o, :grain_duration) { rand(0.01..0.15).round(4) }
    pitch_scatter = ParamOverride.fetch(o, :pitch_scatter_semitones) { rand(0.0..2.0).round(3) }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.3..0.7).round(2) }
    waveform_type = ParamOverride.fetch(o, :waveform_type) { GEN10_BY_WAVEFORM.keys.sample }
    gen10_args = GEN10_BY_WAVEFORM.fetch(waveform_type, "1")

    attack = ParamOverride.fetch(o, :envelope, :attack) { rand(0.2..1.5).round(3) }
    release = ParamOverride.fetch(o, :envelope, :release) { rand(0.3..1.5).round(3) }
    if attack + release > duration * 0.9
      scale = (duration * 0.9) / (attack + release)
      attack = (attack * scale).round(3)
      release = (release * scale).round(3)
    end

    params = {
      base_freq: base_freq,
      grain_density: grain_density,
      grain_duration: grain_dur,
      pitch_scatter_semitones: pitch_scatter,
      amplitude: amplitude,
      waveform_type: waveform_type,
      envelope: { attack: attack, release: release }
    }

    scatter_ratio = 2.0 ** (pitch_scatter / 12.0)

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
        ifreq = #{base_freq}
        idens = #{grain_density}
        igdur = #{grain_dur}

        kenv linseg 0, #{attack}, 1, #{duration} - #{attack} - #{release}, 1, #{release}, 0

        krand randi #{(scatter_ratio - 1).round(6)}, idens
        kpitch = ifreq * (1 + krand)

        aout grain iamp * kenv, kpitch, idens, 0, 0, igdur, 1, 1, 0.5

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 4096 10 #{gen10_args}
      f 2 0 4096 20 2

      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "granular", duration: duration }
  end
end
