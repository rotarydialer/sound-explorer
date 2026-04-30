require_relative "sample_library"

# Partitioned convolution: a synthesised excitation signal (pluck or noise
# burst) convolved with a sample acting as an impulse response. Convolution
# with a real IR → reverb. Convolution with a percussive sample → that
# sample's resonant body imposed onto the excitation.
module SynthConvolution
  module_function

  # Keep IRs short — partitioned convolution memory is O(IR length).
  MAX_IR_DURATION = 10.0
  PARTITION_LENGTH = 1024

  EXCITATIONS = ["pluck", "noise_burst", "tone"].freeze

  def generate(duration: nil, freq: nil)
    duration ||= rand(2.0..5.0).round(2)

    ir_path = SampleLibrary.pick(max_duration: MAX_IR_DURATION)
    ir_dur = SampleLibrary.duration_of(ir_path) || MAX_IR_DURATION

    excitation = EXCITATIONS.sample
    excite_freq = freq || rand(80.0..600.0).round(2)
    excite_amp = rand(0.5..0.8).round(2)
    excite_dur = rand(0.05..0.3).round(3)

    excite_lines =
      case excitation
      when "pluck"
        <<~LINES.strip
          asrc pluck #{excite_amp}, #{excite_freq}, #{excite_freq}, 0, 1
          aenv expseg 1, #{excite_dur}, 0.001, p3 - #{excite_dur}, 0.001
          adry = asrc * aenv
        LINES
      when "noise_burst"
        <<~LINES.strip
          anoise pinkish #{excite_amp}
          aenv expseg 1, #{excite_dur}, 0.001, p3 - #{excite_dur}, 0.001
          adry = anoise * aenv
        LINES
      when "tone"
        <<~LINES.strip
          asrc poscil #{excite_amp}, #{excite_freq}
          aenv linseg 0, 0.005, 1, #{excite_dur}, 0, p3 - #{excite_dur} - 0.005, 0
          adry = asrc * aenv
        LINES
      end

    wet_dry = rand(0.6..1.0).round(3)
    output_gain = rand(0.4..0.9).round(3)

    params = {
      impulse_response: relative_sample_path(ir_path),
      ir_duration: ir_dur,
      excitation: excitation,
      excitation_freq: excite_freq,
      excitation_amplitude: excite_amp,
      excitation_duration: excite_dur,
      wet_dry: wet_dry,
      output_gain: output_gain,
      partition_length: PARTITION_LENGTH
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
        ; Excitation signal
        #{excite_lines.gsub("\n", "\n        ")}

        ; Convolve with the IR sample loaded in table 1.
        awet ftconv adry, 1, #{PARTITION_LENGTH}

        amix = (awet * #{wet_dry}) + (adry * #{(1.0 - wet_dry).round(3)})
        aout = amix * #{output_gain}
        aout clip aout, 0, 0.95

        outs aout, aout
      endin
      </CsInstruments>
      <CsScore>
      f 1 0 0 1 "#{ir_path}" 0 0 1
      i 1 0 #{duration}
      </CsScore>
      </CsoundSynthesizer>
    CSD

    { params: params, csd: csd, synth_type: "convolution", duration: duration }
  end

  def relative_sample_path(path)
    return path unless SampleLibrary.samples_dir
    rel = path.sub(SampleLibrary.samples_dir + File::SEPARATOR, "")
    rel == path ? File.basename(path) : rel
  end
end
