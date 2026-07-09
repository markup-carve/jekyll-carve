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

  spec.add_dependency "carve-lang", ">= 0.1.0"
  spec.add_dependency "jekyll", ">= 4.0"

  spec.add_development_dependency "rspec", "~> 3.0"
end
