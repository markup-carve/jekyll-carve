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
carve_rb = File.expand_path("../carve-rb", __dir__)
if File.directory?(carve_rb)
  # A sibling checkout still wins for local development on carve-rb itself.
  gem "carve-lang", path: carve_rb
else
  gem "carve-lang", git: "https://github.com/markup-carve/carve-rb.git", ref: "57ded5fdf1f9d6d54f175131e2ddbeb4d10af024"
end
