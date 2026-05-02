#!/usr/bin/env ruby
require "optparse"
require "fileutils"
require "time"
require "json"

require_relative "lib/csd_runner"
require_relative "lib/metadata"
require_relative "lib/sample_library"
require_relative "lib/synth_fm"
require_relative "lib/synth_subtractive"
require_relative "lib/synth_additive"
require_relative "lib/synth_granular"
require_relative "lib/synth_karplus"
require_relative "lib/synth_modal"
require_relative "lib/synth_drum"
require_relative "lib/synth_physical"
require_relative "lib/synth_formant"
require_relative "lib/synth_noise"
require_relative "lib/synth_stochastic"
require_relative "lib/synth_waveshape"
require_relative "lib/synth_ringmod"
require_relative "lib/synth_granular_sample"
require_relative "lib/synth_timestretch"
require_relative "lib/synth_spectral_morph"
require_relative "lib/synth_cross_synth"
require_relative "lib/synth_convolution"

SYNTH_TYPES = {
  "fm"               => SynthFm,
  "subtractive"      => SynthSubtractive,
  "additive"         => SynthAdditive,
  "granular"         => SynthGranular,
  "karplus"          => SynthKarplus,
  "modal"            => SynthModal,
  "drum"             => SynthDrum,
  "physical"         => SynthPhysical,
  "formant"          => SynthFormant,
  "noise"            => SynthNoise,
  "stochastic"       => SynthStochastic,
  "waveshape"        => SynthWaveshape,
  "ringmod"          => SynthRingmod,
  "granular_sample"  => SynthGranularSample,
  "timestretch"      => SynthTimestretch,
  "spectral_morph"   => SynthSpectralMorph,
  "cross_synth"      => SynthCrossSynth,
  "convolution"      => SynthConvolution
}.freeze

SAMPLE_BASED_CAPS = {
  "granular_sample" => SynthGranularSample::MAX_SAMPLE_DURATION,
  "timestretch"     => SynthTimestretch::MAX_SAMPLE_DURATION,
  "spectral_morph"  => SynthSpectralMorph::MAX_SAMPLE_DURATION,
  "cross_synth"     => SynthCrossSynth::MAX_SAMPLE_DURATION,
  "convolution"     => SynthConvolution::MAX_IR_DURATION
}.freeze
SAMPLE_BASED_TYPES = SAMPLE_BASED_CAPS.keys.freeze

options = {
  count: 10,
  types: SYNTH_TYPES.keys,
  duration: nil,  # nil means each synth picks its own random duration
  formats: ["ogg"],
  freq: nil,      # nil means each synth picks its own random frequency
  samples_dir: nil,
  samples_info: false,
  params_override: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby generate.rb [options]"

  opts.on("--count N", Integer, "Number of sounds to generate (default: 10)") do |n|
    options[:count] = n
  end

  opts.on("--types TYPES", "Comma-separated synth types: #{SYNTH_TYPES.keys.join(',')}") do |t|
    options[:types] = t.split(",").map(&:strip)
  end

  opts.on("--duration SECS", Float, "Fixed duration in seconds (default: random per sound)") do |d|
    options[:duration] = d
  end

  opts.on("--formats FORMATS", "Comma-separated output formats: ogg,wav (default: ogg)") do |f|
    options[:formats] = f.split(",").map(&:strip)
  end

  opts.on("--freq HZ", Float, "Fixed base frequency in Hz (default: random per sound)") do |f|
    options[:freq] = f
  end

  opts.on("--samples-dir PATH", "Directory containing audio samples (default: $SAMPLES_DIR or ./samples)") do |p|
    options[:samples_dir] = p
  end

  opts.on("--samples-info", "Print info about the configured sample library and exit") do
    options[:samples_info] = true
  end

  opts.on("--params-json JSON", "JSON object of param overrides; applied to every generated sound") do |j|
    options[:params_override] = JSON.parse(j)
  end
end.parse!

SampleLibrary.configure(samples_dir: options[:samples_dir])

if options[:samples_info]
  info = SampleLibrary.info
  puts "Samples dir: #{info[:samples_dir]}"
  puts "Total samples: #{info[:total]}"
  if info[:categories].empty?
    puts "(no top-level subdirectories — all samples treated as a flat pool)"
  else
    puts "Categories:"
    info[:categories].each { |cat, n| puts "  #{cat}: #{n}" }
  end
  exit 0
end

# Validate types
options[:types].each do |t|
  unless SYNTH_TYPES.key?(t)
    abort "Unknown synth type '#{t}'. Available: #{SYNTH_TYPES.keys.join(', ')}"
  end
end

# Sanity-check sample library availability if any sample-based types are requested
sample_types_requested = options[:types] & SAMPLE_BASED_TYPES
if sample_types_requested.any?
  if SampleLibrary.empty?
    abort "Sample-based types requested (#{sample_types_requested.join(', ')}) but no samples found in #{SampleLibrary.samples_dir}.\n" \
          "Set --samples-dir or $SAMPLES_DIR to a directory containing .wav/.aif/.flac files."
  end

  # Probe any uncached durations so the pool-size readout below is accurate.
  SampleLibrary.probe_all!

  total = SampleLibrary.all.size
  puts "Sample library: #{total} file#{'s' if total != 1} in #{SampleLibrary.samples_dir}"
  label_width = sample_types_requested.map(&:length).max
  sample_types_requested.each do |t|
    cap = SAMPLE_BASED_CAPS[t]
    n = SampleLibrary.count_under(cap)
    pct = total > 0 ? (n * 100.0 / total).round : 0
    warn_marker = n < 4 ? "  ⚠ pool is small — bias likely" : ""
    puts "  #{t.ljust(label_width)}  #{n}/#{total} samples ≤ #{cap}s (#{pct}%)#{warn_marker}"
  end
end

# Create batch directory
batch = Time.now.strftime("%Y-%m-%d_%H%M%S")
output_dir = File.join(__dir__, "output", batch)
FileUtils.mkdir_p(output_dir)

puts "Generating #{options[:count]} sounds in #{output_dir}"

counters = Hash.new(0)

options[:count].times do |i|
  synth_type = options[:types][i % options[:types].size]
  synth = SYNTH_TYPES[synth_type]
  counters[synth_type] += 1

  name = "#{synth_type}_%03d" % counters[synth_type]

  print "  [#{i + 1}/#{options[:count]}] #{name}..."

  result = synth.generate(duration: options[:duration], freq: options[:freq], params: options[:params_override])

  paths = CsdRunner.render(result[:csd], output_dir, name, formats: options[:formats])

  meta = Metadata.build(
    name: name,
    synth_type: result[:synth_type],
    batch: batch,
    duration: result[:duration],
    params: result[:params],
    csd_content: result[:csd],
    formats: options[:formats]
  )
  Metadata.save(output_dir, name, meta)

  puts " done (#{result[:duration]}s)"
rescue => e
  puts " FAILED: #{e.message}"
end

SampleLibrary.flush_cache

puts "\nBatch complete: #{output_dir}"
puts "Generated #{counters.map { |k, v| "#{v} #{k}" }.join(', ')}"
