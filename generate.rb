#!/usr/bin/env ruby
require "optparse"
require "fileutils"
require "time"

require_relative "lib/csd_runner"
require_relative "lib/metadata"
require_relative "lib/synth_fm"
require_relative "lib/synth_subtractive"
require_relative "lib/synth_additive"
require_relative "lib/synth_granular"

SYNTH_TYPES = {
  "fm"          => SynthFm,
  "subtractive" => SynthSubtractive,
  "additive"    => SynthAdditive,
  "granular"    => SynthGranular
}.freeze

options = {
  count: 10,
  types: SYNTH_TYPES.keys,
  duration: nil,  # nil means each synth picks its own random duration
  formats: ["ogg"]
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
end.parse!

# Validate types
options[:types].each do |t|
  unless SYNTH_TYPES.key?(t)
    abort "Unknown synth type '#{t}'. Available: #{SYNTH_TYPES.keys.join(', ')}"
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

  result = synth.generate(duration: options[:duration])

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

puts "\nBatch complete: #{output_dir}"
puts "Generated #{counters.map { |k, v| "#{v} #{k}" }.join(', ')}"
