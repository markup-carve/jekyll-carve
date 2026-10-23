# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The engine is the RELEASED carve-lang gem, pinned to an exact version, so a
# development run measures a version a consumer can install. It used to be a
# carve-rb git revision; released versions replaced that once carve-rb shipped
# precompiled gems on every platform CI runs.
#
# The exact version and the gemspec floor are different claims. The floor is
# the oldest engine this plugin works with; this pin is the engine the suite
# measures, moved forward as carve-lang releases. `script/verify_engine_pin.rb`
# reads it back in CI: the Gemfile, the resolved bundle and the loaded library
# must name the same version, from RubyGems.
#
# There is no committed Gemfile.lock: bundler 4 lockfiles need Ruby >= 3.2,
# and CI still runs a 3.1 leg.
#
# CARVE_RB_PATH swaps in a local carve-rb checkout for development. It is
# opt-in, and verify_engine_pin.rb refuses a run that used it.
carve_rb = ENV["CARVE_RB_PATH"]
if carve_rb && !carve_rb.empty?
  raise "CARVE_RB_PATH=#{carve_rb} is not a directory" unless File.directory?(carve_rb)

  gem "carve-lang", path: File.expand_path(carve_rb)
else
  gem "carve-lang", "0.1.11"
end
