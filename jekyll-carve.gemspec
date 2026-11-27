# frozen_string_literal: true

require_relative "lib/jekyll/carve/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-carve"
  spec.version = Jekyll::Carve::VERSION
  spec.authors = ["markup-carve"]
  spec.summary = "Jekyll converter for the Carve markup language."
  spec.description = <<~DESC.strip
    A Jekyll plugin that renders Carve (.crv) pages to HTML. It is a
    thin Jekyll::Converter over the native `carve-lang` gem (Carve.to_html);
    no parser is reimplemented.
  DESC
  spec.homepage = "https://github.com/markup-carve/jekyll-carve"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE"
  ]
  spec.require_paths = ["lib"]
  # Every push must come from an account with MFA enabled. Combined with the
  # trusted publisher on rubygems.org, releases are authorized by the
  # provenance of the CI request rather than by a stored key, and a leaked
  # credential cannot publish this gem at all.
  spec.metadata = {
    "rubygems_mfa_required" => "true",
  }


  # The range is the 0.2 line only: on this org's 0.x line `0.2` is the major,
  # so < 0.3.0 admits every 0.2 minor and stops at the next breaking engine.
  # `Gemfile` pins a carve-rb revision for development instead; see that file.
  spec.add_dependency "carve-lang", ">= 0.2.0", "< 0.3.0"
  spec.add_dependency "jekyll", ">= 4.0"

  spec.add_development_dependency "rspec", "~> 3.0"
end
