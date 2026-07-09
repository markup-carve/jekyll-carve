# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The Carve parser gem (`carve-lang`) is a native extension over the carve-rs
# engine and is not yet on RubyGems. Prefer a sibling checkout for local dev;
# otherwise pull it straight from GitHub (it compiles its Rust extension at
# install time, so a Rust toolchain is required).
carve_rb = File.expand_path("../carve-rb", __dir__)
if File.directory?(carve_rb)
  gem "carve-lang", path: carve_rb
else
  gem "carve-lang", git: "https://github.com/markup-carve/carve-rb.git"
end
