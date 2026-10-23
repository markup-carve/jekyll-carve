#!/usr/bin/env ruby
# frozen_string_literal: true

# WHAT ENGINE DID THIS RUN ACTUALLY MEASURE?
#
# `Gemfile` pins carve-lang to an exact released version. A pin nothing reads
# back is not a pin. Three ways of measuring a different engine all left
# `bundle exec rspec` green and said nothing:
#
#   * the version is dropped or loosened, so the bundle floats;
#   * `CARVE_RB_PATH` is set in the environment, which swaps the pinned engine
#     for whatever a sibling working tree is parked on - the failure #3 was
#     opened for, where a suite was 12 of 12 green over an engine that still
#     rendered `javascript:` out of a list-valued URL attribute;
#   * a restored bundler cache resolved before the pin last moved.
#
# So this runs under `bundle exec` and refuses unless the Gemfile, the resolved
# bundle and the loaded library all name the same engine. It prints that engine
# on success, so a run's result can be read against the thing that produced it.
#
# It reads `Gemfile.lock` - the one `bundle install` just wrote, not a committed
# one; see the Gemfile for why this repository has none - because that file is
# where bundler records what it RESOLVED, as opposed to what was asked for.

ENGINE = "carve-lang"
REGISTRY = "rubygems.org"

def refuse(message)
  # GitHub renders `::error::` as an annotation; elsewhere it is just a prefix.
  warn "::error::#{message}"
  exit 1
end

# --- 1. What does the Gemfile ask for? ---------------------------------------

gemfile = File.read("Gemfile")
pinned = gemfile[/^\s*gem\s+["']#{ENGINE}["'],\s*["']=?\s*(\d+\.\d+\.\d+)["']/, 1]
if pinned.nil?
  refuse "Gemfile names no exact #{ENGINE} version, so this run measured an unstated engine"
end

# --- 2. What did bundler resolve? --------------------------------------------

refuse "no Gemfile.lock, so bundler has not resolved anything to verify" unless File.exist?("Gemfile.lock")

# The lockfile grammar is a section header in column 0, two-space keys, and
# four-space spec lines. Parsed here rather than through Bundler's internals so
# this keeps working across the bundler versions the CI matrix installs.
blocks = []
current = nil
File.read("Gemfile.lock").each_line do |line|
  case line
  when /^([A-Z][A-Z ]*)$/
    current = { kind: Regexp.last_match(1).strip, specs: [] }
    blocks << current
  when /^  (remote|revision|ref):[ \t]*(.+)$/
    current[Regexp.last_match(1).to_sym] = Regexp.last_match(2).strip if current
  when /^ {4}([A-Za-z0-9_.-]+) \(([^)]+)\)$/
    current[:specs] << [Regexp.last_match(1), Regexp.last_match(2)] if current
  end
end

owner = blocks.find { |b| b[:specs].any? { |(name, _)| name == ENGINE } }
refuse "the resolved bundle contains no #{ENGINE} at all" if owner.nil?

# A platform gem resolves as `0.1.11-x86_64-linux`; the version is the part
# before the platform.
resolved_version = owner[:specs].find { |(name, _)| name == ENGINE }.last.split("-").first

case owner[:kind]
when "GEM"
  unless owner[:remote].to_s.include?(REGISTRY)
    refuse "#{ENGINE} was resolved from #{owner[:remote]}, which is not #{REGISTRY}"
  end
  unless resolved_version == pinned
    refuse "Gemfile pins #{ENGINE} #{pinned}, but this bundle resolved #{resolved_version}"
  end
when "PATH"
  refuse "#{ENGINE} was resolved from the path #{owner[:remote]}, not the pinned " \
         "#{pinned} - CARVE_RB_PATH is set, so this run measured a working tree"
else
  refuse "#{ENGINE} was resolved from #{owner[:kind].downcase} (#{owner[:remote]}) " \
         "rather than from #{REGISTRY} at #{pinned}"
end

# --- 3. Is that the library that actually loads? -----------------------------

begin
  require "carve"
rescue LoadError => e
  refuse "#{ENGINE} is in the bundle but does not load: #{e.message}"
end

loaded = Carve::VERSION
unless loaded == resolved_version
  refuse "the bundle resolved #{ENGINE} #{resolved_version} but #{loaded} is what loaded"
end

puts "#{ENGINE} #{loaded} from #{owner[:remote]} (Gemfile pins #{pinned})"
