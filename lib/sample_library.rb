require "json"
require "open3"

# Index and access for the user's sample library.
#
# Configure once at startup with `SampleLibrary.configure(samples_dir: path)`.
# Modules then call `SampleLibrary.pick(category:, max_duration:)` to get a
# random sample path filtered by those constraints.
#
# Sample durations are probed lazily with ffprobe and persisted to a cache
# file (.sample_durations.json) inside the samples directory, so each file
# is only probed once across all runs.
module SampleLibrary
  extend self

  AUDIO_EXTENSIONS = %w[wav aif aiff flac].freeze
  CACHE_FILENAME = ".sample_durations.json"

  def configure(samples_dir: nil)
    dir = samples_dir || ENV["SAMPLES_DIR"] || File.expand_path("../samples", __dir__)
    @samples_dir = File.expand_path(dir)
    @files = scan(@samples_dir)
    @cache_path = File.join(@samples_dir, CACHE_FILENAME) if Dir.exist?(@samples_dir)
    @durations = load_cache
    @cache_dirty = false
    self
  end

  def configured?
    !@samples_dir.nil?
  end

  def samples_dir
    @samples_dir
  end

  def all
    @files || []
  end

  def empty?
    all.empty?
  end

  # Top-level subdirectory names act as categories.
  def categories
    return [] if @samples_dir.nil?
    all.map { |f| relative_category(f) }.compact.uniq.sort
  end

  # Pick a random sample matching the constraints.
  # Raises if no candidates remain.
  #   category:     restrict to a top-level subdirectory name (or nil for any)
  #   max_duration: filter out files longer than N seconds (probes lazily)
  def pick(category: nil, max_duration: nil)
    raise "SampleLibrary not configured" unless configured?
    raise "No samples found in #{@samples_dir}" if empty?

    candidates = all
    if category
      candidates = candidates.select { |f| relative_category(f) == category }
      raise "No samples in category '#{category}'" if candidates.empty?
    end

    if max_duration
      # Probe in random order so we don't bias toward early filenames; stop
      # once we have enough candidates to pick from with reasonable variety.
      shuffled = candidates.shuffle
      filtered = []
      shuffled.each do |path|
        d = duration_of(path)
        filtered << path if d && d <= max_duration
        break if filtered.size >= 32
      end
      raise "No samples ≤ #{max_duration}s (category=#{category || 'any'})" if filtered.empty?
      candidates = filtered
    end

    flush_cache
    candidates.sample
  end

  # Probe duration via ffprobe; cached for the life of the samples dir.
  # Returns Float seconds or nil on probe failure.
  def duration_of(path)
    cached = @durations[path]
    return cached if cached

    out, status = Open3.capture2e(
      "ffprobe", "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      path
    )

    duration = status.success? ? out.strip.to_f : nil
    duration = nil if duration && duration <= 0
    @durations[path] = duration
    @cache_dirty = true
    duration
  end

  def info
    {
      samples_dir: @samples_dir,
      total: all.size,
      categories: categories.map { |c| [c, all.count { |f| relative_category(f) == c }] }.to_h
    }
  end

  # Probe any uncached durations so subsequent count_under calls are accurate.
  # Prints progress dots for large libraries. Cheap on subsequent runs.
  def probe_all!
    uncached = all.reject { |f| @durations.key?(f) }
    return if uncached.empty?

    show_progress = uncached.size >= 50
    print "Probing #{uncached.size} sample#{'s' if uncached.size != 1} for duration" if show_progress
    uncached.each_with_index do |path, i|
      duration_of(path)
      print "." if show_progress && (i + 1) % 25 == 0
    end
    puts " done." if show_progress
    flush_cache
  end

  # Count samples with a known duration ≤ max_duration.
  # Files that have not been probed yet are not counted — call probe_all! first
  # for an accurate number.
  def count_under(max_duration)
    all.count { |f| (d = @durations[f]) && d <= max_duration }
  end

  def flush_cache
    return unless @cache_dirty && @cache_path
    File.write(@cache_path, JSON.pretty_generate(@durations))
    @cache_dirty = false
  end

  private

  def scan(dir)
    return [] unless Dir.exist?(dir)
    pattern = File.join(dir, "**", "*.{#{AUDIO_EXTENSIONS.join(",")}}")
    Dir.glob(pattern, File::FNM_CASEFOLD).sort
  end

  def load_cache
    return {} unless @cache_path && File.exist?(@cache_path)
    JSON.parse(File.read(@cache_path))
  rescue JSON::ParserError
    {}
  end

  # Returns the top-level subdirectory name relative to samples_dir,
  # or nil if the file lives at the root.
  def relative_category(path)
    rel = path.sub(@samples_dir + File::SEPARATOR, "")
    parts = rel.split(File::SEPARATOR)
    parts.size > 1 ? parts.first : nil
  end
end
