require_relative "param_override"

module SynthDrum
  module_function

  ARCHETYPES = ["kick", "snare", "tom", "hat", "perc"].freeze

  def generate(duration: nil, freq: nil, params: nil)
    o = params
    archetype = ParamOverride.fetch(o, :archetype) { ARCHETYPES.sample }
    duration = ParamOverride.fetch(o, :duration) { duration || rand(0.4..2.0).round(2) }
    amplitude = ParamOverride.fetch(o, :amplitude) { rand(0.5..0.85).round(2) }

    case archetype
    when "kick"
      body_freq_d = freq || rand(45.0..90.0).round(2)
      pitch_sweep_mult_d = rand(3.0..8.0).round(2)
      sweep_dur_d = rand(0.03..0.12).round(3)
      body_decay_d = rand(0.15..0.5).round(3)
      click_amp_d = rand(0.05..0.25).round(3)
      click_decay_d = rand(0.005..0.025).round(4)
      hp_cut_d = rand(800.0..2500.0).round(0)
    when "snare"
      body_freq_d = freq || rand(150.0..280.0).round(2)
      pitch_sweep_mult_d = rand(1.0..2.5).round(2)
      sweep_dur_d = rand(0.005..0.03).round(4)
      body_decay_d = rand(0.05..0.18).round(3)
      click_amp_d = rand(0.4..0.7).round(3)
      click_decay_d = rand(0.08..0.25).round(3)
      hp_cut_d = rand(500.0..1500.0).round(0)
    when "tom"
      body_freq_d = freq || rand(80.0..220.0).round(2)
      pitch_sweep_mult_d = rand(2.0..4.0).round(2)
      sweep_dur_d = rand(0.04..0.12).round(3)
      body_decay_d = rand(0.25..0.7).round(3)
      click_amp_d = rand(0.05..0.15).round(3)
      click_decay_d = rand(0.005..0.02).round(4)
      hp_cut_d = rand(1000.0..3000.0).round(0)
    when "hat"
      body_freq_d = freq || rand(800.0..3000.0).round(2)
      pitch_sweep_mult_d = 1.0
      sweep_dur_d = 0.001
      body_decay_d = rand(0.005..0.02).round(4)
      click_amp_d = rand(0.5..0.8).round(3)
      click_decay_d = rand(0.03..0.15).round(3)
      hp_cut_d = rand(4000.0..9000.0).round(0)
    else
      body_freq_d = freq || rand(200.0..1200.0).round(2)
      pitch_sweep_mult_d = rand(1.5..4.0).round(2)
      sweep_dur_d = rand(0.005..0.04).round(4)
      body_decay_d = rand(0.05..0.3).round(3)
      click_amp_d = rand(0.2..0.5).round(3)
      click_decay_d = rand(0.01..0.05).round(4)
      hp_cut_d = rand(2000.0..6000.0).round(0)
    end

    body_freq = ParamOverride.fetch(o, :body_freq) { body_freq_d }
    pitch_sweep_mult = ParamOverride.fetch(o, :pitch_sweep_mult) { pitch_sweep_mult_d }
    sweep_dur = ParamOverride.fetch(o, :pitch_sweep_duration) { sweep_dur_d }
    body_decay = ParamOverride.fetch(o, :body_decay) { body_decay_d }
    click_amp = ParamOverride.fetch(o, :click_amplitude) { click_amp_d }
    click_decay = ParamOverride.fetch(o, :click_decay) { click_decay_d }
    hp_cut = ParamOverride.fetch(o, :noise_highpass) { hp_cut_d }

    pitch_start = (body_freq * pitch_sweep_mult).round(2)

    params = {
      archetype: archetype,
      body_freq: body_freq,
      amplitude: amplitude,
      pitch_sweep_mult: pitch_sweep_mult,
      pitch_sweep_duration: sweep_dur,
      body_decay: body_decay,
      click_amplitude: click_amp,
      click_decay: click_decay,
      noise_highpass: hp_cut
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
        ibodyfreq = #{body_freq}
        ipitchstart = #{pitch_start}

        kbodypitch expsegr ipitchstart, #{sweep_dur}, ibodyfreq, p3 - #{sweep_dur}, ibodyfreq
        abody poscil iamp, kbodypitch
        kbodyenv expsegr 1, #{body_decay}, 0.001, p3 - #{body_decay}, 0.001
        abody = abody * kbodyenv

        anoise pinkish #{click_amp}
        kclickenv expsegr 1, #{click_decay}, 0.001, p3 - #{click_decay}, 0.001
        aclick = anoise * kclickenv
        aclick butterhp aclick, #{hp_cut}

        amix = abody + aclick
        aout clip amix, 0, 0.95

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "drum", duration: duration }
  end
end
