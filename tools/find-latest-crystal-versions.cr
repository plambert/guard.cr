#!/usr/bin/env cryun

# use the `podman search` command to find all the docker images for the crystal
# language, or just those for released versions, or just those for the latest
# point release for each minor version...

# ---
# guard:
#   github: plambert/guard.cr
# ...

require "../lib/guard/src/guard"

class CLI
  include Guard

  enum Mode
    All
    Release
    Latest
  end

  struct Tag
    include Comparable(self)
    property name : String
    property major : Int32?
    property minor : Int32?
    property patch : Int32?
    property flags : Set(String) = Set(String).new
    property comparable_tuple : {Int32, Int32, Int32, Array(String), String} do
      self.generate_comparable_tuple
    end

    def initialize(@name)
      if @name =~ %r{^\d+(?:\.\d+){2}(?:-\w+)*$}
        if @name =~ %r{^(\d+)}
          @major = $1.to_i
          if @name =~ %r{^\d+\.(\d+)}
            @minor = $1.to_i
            if @name =~ %r{\d+\.\d+\.(\d+)}
              @patch = $1.to_i
            end
          end
        end
      end
      if @name =~ %r{^[\d\.]*((?:-\w+)+)$}
        $1[1..].split('-').each do |flag|
          flags.add flag
        end
      end
    end

    def <=>(other : self)
      # if structured? && other.structured?
      comparable_tuple <=> other.comparable_tuple
      # elsif structured?
      #   -1
      # elsif other.structured?
      #   1
      # else
      #   name <=> other.name
      # end
    end

    def generate_comparable_tuple
      {@major || 0, @minor || 0, @patch || 0, @flags.to_a.sort!, @name}
    end

    def to_s(io)
      if int = @major
        io << int
        if int = @minor
          io << '.'
          io << int
          if int = @patch
            io << '.'
            io << int
          end
        end
        flags.each do |flag|
          io << '-'
          io << flag
        end
      else
        io << @name
      end
    end

    def structured?
      @major && @minor && @patch
    end

    def release?
      structured? && flags.empty?
    end
  end

  IMAGE_NAME            = "docker.io/crystallang/crystal"
  PODMAN_SEARCH_COMMAND = %w[podman search --limit 100000 --list-tags]

  property search_command : Array(String) = PODMAN_SEARCH_COMMAND
  property image_name : String = IMAGE_NAME
  property mode : Mode = Mode::Release
  property minimum : Tag? = nil

  def initialize(opts = ARGV.dup)
    while opt = opts.shift?
      case opt
      when "--all"
        @mode = Mode::All
      when "--release", "--releases"
        @mode = Mode::Release
      when "--latest"
        @mode = Mode::Latest
      when "--image"
        @image_name = opts.shift
      when %r{^--\d+\.\d+\.\d+$}
        @minimum = Tag.new opt[2..]
      else
        raise ArgumentError.new "#{opt}: unknown option"
      end
    end

    if @minimum && !@mode.release? && !@mode.latest?
      raise ArgumentError.new "cannot give a minimum version in mode #{@mode}"
    end

    @search_command = PODMAN_SEARCH_COMMAND
    @search_command << @image_name
  end

  def run
    tags = [] of Tag

    Process.run(
      command: PODMAN_SEARCH_COMMAND[0],
      args: PODMAN_SEARCH_COMMAND[1..],
      input: Process::Redirect::Close,
      error: STDERR,
    ) do |proc|
      proc.output.each_line(chomp: true) do |line|
        if line =~ %r{^docker\.io/crystallang/crystal\s+(.*)$}
          tags << Tag.new($1)
        end
      end
    end

    if minimum_tag = minimum
      tags.reject! { |tag| tag < minimum_tag }
    end

    case @mode
    in .all?
      tags.each { |tag| puts tag }
    in .release?
      tags.select! &.structured?
      tags.sort!.each { |rel| puts rel }
      # tags.select(&.matches? %r{^\d+\.\d+\.\d+$}).each { |tag| puts tag }
    in .latest?
      latest = {} of {Int32, Int32} => Tag
      tags.select(&.release?).each do |tag|
        major = tag.major || 0
        minor = tag.minor || 0
        patch = tag.patch || 0
        latest[{major, minor}] = tag if (latest[{major, minor}]?.try(&.patch) || 0) < patch
      end
      latest.values.sort!.each do |tag|
        puts tag
      end
    end
  end
end

begin
  cli = CLI.new
  cli.run
rescue e : ArgumentError
  STDERR.printf "%s [ERROR] %s\n", PROGRAM_NAME, e
  exit 1
end
