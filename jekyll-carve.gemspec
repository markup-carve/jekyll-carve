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


  # THE FLOOR. >= 0.1.1, not 0.1.0, for two independent reasons - carve-lang
  # 0.1.0 predates the Carve 0.1.3 security release and renders a list-valued
  # URL attribute unsanitized, and it does not accept the `symbols:` keyword
  # `Converter#convert` passes, so it raises on every page. Both are measured
  # by spec/engine_floor_spec.rb rather than left standing on this comment.
  #
  # The floor is a claim about the OLDEST engine this plugin works with, so it
  # moves when an older engine stops working - never because a newer one
  # exists. Raising it is also not a way to bound anything: >= 0.1.2 would be
  # exactly as open at the top as >= 0.1.1 was.
  #
  # THE CEILING follows from the engine's own versioning rather than from a
  # judgement about its API surface. On this org's 0.x line `0.1` is the major
  # and the third digit is the minor, so < 0.2.0 admits every engine minor
  # (0.1.2, 0.1.3, ...) and excludes only a release the engine itself declares
  # breaking. It is not a cap to relax at each engine minor; it is the point at
  # which someone has to look. Without it this range admitted, by the engine's
  # own rules, exactly the changes that break this plugin.
  #
  # A range is the right shape for a consumer and the wrong one for a test run,
  # so `Gemfile` pins a carve-rb revision for development instead. Those are
  # different engines on purpose; see that file.
  spec.add_dependency "carve-lang", ">= 0.1.1", "< 0.2.0"
  spec.add_dependency "jekyll", ">= 4.0"

  spec.add_development_dependency "rspec", "~> 3.0"
end
