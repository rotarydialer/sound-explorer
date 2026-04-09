require "open3"
require "tempfile"
require "fileutils"

module CsdRunner
  module_function

  # Renders a CSD string to WAV and OGG files in output_dir.
  # Returns { wav: path, ogg: path } on success, raises on failure.
  def render(csd_content, output_dir, name, formats: ["ogg"])
    wav_path = File.join(output_dir, "#{name}.wav")
    ogg_path = File.join(output_dir, "#{name}.ogg")

    # Write CSD to a temp file
    tmp = Tempfile.new(["sound", ".csd"])
    begin
      tmp.write(csd_content)
      tmp.flush

      # Csound always renders to WAV natively
      out, status = Open3.capture2e("csound", "-W", "-d", "-o", wav_path, tmp.path)
      unless status.success?
        raise "csound failed for #{name}:\n#{out}"
      end
    ensure
      tmp.close
      tmp.unlink
    end

    result = {}

    if formats.include?("ogg")
      out, status = Open3.capture2e("ffmpeg", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", ogg_path)
      unless status.success?
        raise "ffmpeg failed for #{name}:\n#{out}"
      end
      result[:ogg] = ogg_path
    end

    if formats.include?("wav")
      result[:wav] = wav_path
    else
      File.delete(wav_path)
    end

    result
  end
end
