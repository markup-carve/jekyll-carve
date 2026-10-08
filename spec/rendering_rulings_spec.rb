# frozen_string_literal: true

# RULINGS THE ENGINE HAS MOVED ON, ASSERTED AS RULINGS RATHER THAN GOLDENS.
#
# The suite had no example that could see a rendering change. `engine_floor_spec`
# asks whether sanitization still holds and whether the keyword arguments the
# converter passes are still accepted - both about the engine remaining usable,
# neither about what it renders. `converter_spec` and `includes_spec` cover this
# plugin's own wiring. So between carve-rb v0.1.4 and v0.1.7, four of seven
# boundary shapes rendered differently and every one of the 64 examples stayed
# green.
#
# What those four were, measured through the pinned bundle at v0.1.4 and through
# a consumer install at 0.1.7, in separate processes:
#
#   * a cross-reference differing only in case resolved to a link, and now stays
#     literal text;
#   * a named container with an unseparated metadata slot was a paragraph of
#     literal text (with the quote smart-folded to ”), and now opens the
#     container;
#   * explicit table body counts leaked into the output as a `body-rows`
#     attribute on `<table>` and produced one `<tbody>`, and are now consumed
#     into two;
#   * a fence in a description body carried a stray newline inside its `<code>`.
#
# Each example below asserts the DIRECTION of the ruling - a link or not a link,
# an attribute leaked or consumed - and not a byte string the engine happens to
# produce. A golden here would pin whatever the current engine says, including a
# reading that later turns out wrong; a direction is a claim this plugin can hold
# the engine to. Every one of them fails on v0.1.4, which is the only evidence
# that they are measuring the engine rather than restating it.
#
# These are the engine's rulings, not this plugin's behavior. They live here
# because a Jekyll site renders `.crv` through `Converter#convert`, so a change
# in any of them is a change in a published page.

require "carve"
require "jekyll-carve"

RSpec.describe "engine rulings a published page depends on" do
  def render(source)
    Jekyll::Carve::Converter.new({}).convert(source)
  end

  it "renders anything at all, so the assertions below cannot pass on empty output" do
    # The discriminator, for the same reason engine_floor_spec carries one: an
    # engine that rendered nothing would satisfy every `not_to include` below.
    expect(render("# T\n\nBody.\n")).to include("<h1", "Body")
  end

  describe "a name lookup compares case exactly" do
    let(:source) { "{#Getting-Started}\n# Getting Started\n\nSee </#getting-started> and </#Getting-Started>.\n" }

    it "leaves a cross-reference whose target differs only in case as literal text" do
      expect(render(source)).to include("&lt;/#getting-started&gt;")
    end

    it "still resolves the spelling that matches" do
      expect(render(source)).to include(%(<a href="#Getting-Started">))
    end
  end

  describe "explicit table body counts" do
    let(:source) { "{header-rows=1 body-rows=1,1}\n| H | G |\n| a | b |\n| c | d |\n" }

    it "does not leak the metadata into the rendered table as an attribute" do
      expect(render(source)).not_to include("body-rows="),
                                    "carve-lang #{Carve::VERSION} published the row-count metadata as an HTML attribute"
    end

    it "assembles the two bodies the counts name" do
      expect(render(source).scan("<tbody>").length).to eq(2)
    end
  end

  describe "a named container whose metadata slot is not separated by a space" do
    let(:source) { %(::: note"Title\nBody.\n:::\n) }

    it "opens the container rather than rendering the opener as prose" do
      html = render(source)
      expect(html).to include("admonition")
      expect(html).not_to include("::: note")
    end
  end

  describe "a fence that is a description body's own block" do
    let(:source) { ":: t\n: ```\ncode\n```\n" }

    it "gives the empty payload no content" do
      expect(render(source)).to include("<pre><code></code></pre>")
    end
  end
end
