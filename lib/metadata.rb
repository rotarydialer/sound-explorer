require "json"
require "time"

module Metadata
  module_function

  def save(output_dir, name, data)
    path = File.join(output_dir, "#{name}.json")
    File.write(path, JSON.pretty_generate(data))
    path
  end

  def load(json_path)
    JSON.parse(File.read(json_path))
  end

  # Build a complete metadata hash for a generated sound.
  def build(name:, synth_type:, batch:, duration:, params:, csd_content:, sample_rate: 44100, formats: ["ogg"])
    files = {}
    files[:ogg] = "#{name}.ogg" if formats.include?("ogg")
    files[:wav] = "#{name}.wav" if formats.include?("wav")

    {
      name: name,
      synth_type: synth_type,
      batch: batch,
      created_at: Time.now.utc.iso8601,
      duration_seconds: duration,
      sample_rate: sample_rate,
      params: params,
      csd_content: csd_content,
      files: files,
      tags: [],
      description: ""
    }
  end
end
