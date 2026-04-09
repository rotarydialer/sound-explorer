module SynthGranular
  module_function

  def generate(duration: nil)
    duration ||= rand(2.0..6.0).round(2)
    base_freq = rand(100.0..800.0).round(2)
    grain_density = rand(5.0..80.0).round(1)     # grains per second
    grain_dur = rand(0.01..0.15).round(4)          # seconds per grain
    pitch_scatter = rand(0.0..2.0).round(3)        # semitones of random scatter
    amplitude = rand(0.3..0.7).round(2)

    # Source waveform for grains: sine, triangle, or sawtooth
    # Using GEN10 for different timbres
    waveform_type = ["sine", "bright", "hollow"].sample
    gen10_args = case waveform_type
                 when "sine"   then "1"
                 when "bright" then "1 0.5 0.3 0.2 0.1"
                 when "hollow" then "1 0 0.3 0 0.1"
                 end

    # Amplitude envelope for the overall sound
    attack = rand(0.2..1.5).round(3)
    release = rand(0.3..1.5).round(3)
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

    # pitch_scatter as a frequency ratio range
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

        ; Overall amplitude envelope (fade in/out)
        kenv linseg 0, #{attack}, 1, #{duration} - #{attack} - #{release}, 1, #{release}, 0

        ; Grain generation using granule opcode alternative:
        ; We use fog for overlapping grains with pitch variation
        ; Simple approach: use multiple random-triggered grains via schedkwhen

        ; Randomized pitch per k-cycle
        krand randi #{(scatter_ratio - 1).round(6)}, idens
        kpitch = ifreq * (1 + krand)

        ; Grain stream using grain opcode
        aout grain iamp * kenv, kpitch, idens, 0, 0, igdur, 1, 1, 0.5

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      ; Grain waveform table
      f 1 0 4096 10 #{gen10_args}
      ; Hanning window for grain envelope
      f 2 0 4096 20 2

      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "granular", duration: duration }
  end
end
