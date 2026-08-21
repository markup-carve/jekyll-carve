# frozen_string_literal: true

# WHETHER THE ENGINE THIS PLUGIN RESOLVES IS ONE THE FLOOR ACTUALLY ADMITS.
#
# `jekyll-carve.gemspec` declares a RANGE, so what a consumer installs is
# whatever RubyGems serves inside it. That is not something this repository can
# read off its own manifest - the manifest looks current either way - and no
# other spec here asks. Measured against carve-lang 0.1.0, the engine the floor
# excludes: 11 of the 38 existing examples fail, and every one of them fails on
# `unknown keyword: :symbols`. Not one mentions `javascript:`. So an engine that
# regressed ONLY the sanitization, keeping the API this plugin calls, would
# leave the suite entirely green - which is what this file is for.
#
# The floor is `>= 0.1.1`, and it rests on two independent claims, both measured
# here rather than asserted in a comment. Both were verified against carve-lang
# 0.1.0 and 0.1.1 on 2026-08-21.
#
# 1. SANITIZATION. carve-lang 0.1.0 probed a list-valued URL attribute only on
#    its FIRST entry, so a payload in the second was never sanitized:
#
#      carve-lang 0.1.0 -> <img src="x.png" alt="a"
#                               srcset="safe.png 1x, javascript:alert(1) 2x">
#      carve-lang 0.1.1 -> <img src="x.png" alt="a" srcset="">
#
# 2. THE API THE CONVERTER CALLS. `Converter#convert` passes `symbols:`, which
#    carve-lang 0.1.0 does not accept - it raises `ArgumentError: unknown
#    keyword: :symbols` on every page. That arrived with the symbol map in #8
#    and had nothing recording it, so the floor is now required for a second
#    reason that no comment stated.
#
# Raising the floor is a decision about what STOPPED working, never about what
# is newest - see the Gemfile for how the floor and the development pin move
# separately. `.github/workflows/release.yml` asks the sanitization question of
# the engine a CONSUMER resolves from RubyGems; this file asks it of the engine
# under `bundle exec rspec`, and they are not the same engine.

require "carve"
require "jekyll-carve"

RSpec.describe "the carve-lang floor" do
  let(:source) { %q(![a](x.png){srcset="safe.png 1x, javascript:alert(1) 2x"}) }

  describe "sanitization of a list-valued URL attribute" do
    subject(:html) { Carve.to_html(source) }

    it "renders the image at all" do
      # The discriminator. Without it, an engine that raised, rendered nothing,
      # or dropped the element would satisfy the assertion below by producing
      # no output - and the floor would be "checked" by an example that cannot
      # fail for the reason it exists.
      expect(html).to include("<img")
      expect(html).to include(%(src="x.png"))
    end

    it "drops a javascript: URL from a NON-FIRST entry" do
      expect(html).not_to include("javascript:"),
                          "the resolved carve-lang (#{Carve::VERSION}) emitted an unsanitized " \
                          "javascript: URL from a list-valued attribute: #{html.strip}"
    end
  end

  describe "the keyword arguments Converter#convert passes" do
    it "are all accepted by the resolved engine" do
      expect { Jekyll::Carve::Converter.new({}).convert("# x") }
        .not_to raise_error
    end
  end
end
