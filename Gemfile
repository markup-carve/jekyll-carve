# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The Carve parser gem (`carve-lang`) is a native extension over the carve-rs
# engine. It compiles its Rust extension at install time, so a Rust toolchain is
# required either way.
#
# It IS on RubyGems now, at 0.1.0 - but that release predates most of this
# summer's language work, and carve-rb's 0.1.1 is still an unpublished draft
# (carve#499). So the git source is deliberate, not an oversight, and it stays
# until the gem catches up.
#
# PINNED to a revision. Without a ref this floated on whatever sat on the
# default branch at install time, so CI and a contributor could resolve
# different engines with nothing to read that said so.
# The sibling-checkout escape hatch is OPT-IN, and that is not a style
# preference. It used to trigger on `File.directory?`, so merely HAVING a
# carve-rb checkout beside this one silently replaced the pinned engine with
# whatever that working tree happened to be parked on - no output, nothing in
# the diff, and `Gemfile.lock` recording a PATH source that a contributor
# without the sibling never sees.
#
# Measured here rather than supposed. With a sibling parked on a commit from
# the day before, `bundle exec rspec` was 12 of 12 green while the engine under
# it still rendered:
#
#   ![x](safe.png){srcset="safe.png 1x, javascript:alert(1) 2x"}
#   -> <img src="safe.png" alt="x" srcset="safe.png 1x, javascript:alert(1) 2x">
#
# Bumping the `ref:` below changed nothing, because the ref branch was never
# taken. An env var has to be set on purpose, so the surprising resolution is
# the one you asked for.
carve_rb = ENV["CARVE_RB_PATH"]
if carve_rb && !carve_rb.empty?
  raise "CARVE_RB_PATH=#{carve_rb} is not a directory" unless File.directory?(carve_rb)

  gem "carve-lang", path: File.expand_path(carve_rb)
else
  gem "carve-lang", git: "https://github.com/markup-carve/carve-rb.git", ref: "2773de060de1101d088be6d13fa5ebe3cda3771e"
end
