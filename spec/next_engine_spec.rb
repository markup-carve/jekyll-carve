# frozen_string_literal: true

# Readings and lint rules the carve-lang release after 0.1.13 brings to a
# published page. Each one fails on 0.1.13, which is what shows it measures the
# engine. Like rendering_rulings_spec, these assert a direction, not a golden.

require "carve"
require "jekyll-carve"

RSpec.describe "the engine release after carve-lang 0.1.13" do
  def render(source)
    Jekyll::Carve::Converter.new({}).convert(source)
  end

  describe "braced table cell alignment (carve#5091)" do
    let(:source) { "|={<} A |={>} B |\n| a | b |\n" }

    it "aligns the column rather than printing the braces as cell text" do
      html = render(source)
      expect(html).to include(%(<th scope="col" style="text-align: left;">A</th>))
      expect(html).not_to include("={")
    end
  end

  describe "the glued 0.1.13 alignment markers" do
    let(:source) { "|=< A |=> B |\n| a | b |\n" }

    # U-056: in 0.2 the glued prefix is cell text, not an alignment.
    it "still render as alignment" do
      expect(render(source)).to include(%(<th scope="col">&gt; B</th>))
    end
  end

  describe "an erased comment line (carve#5012)" do
    it "folds the paragraphs around it into one" do
      expect(render("a\n%% c\nb\n")).to include("<p>a\nb</p>")
    end
  end

  describe "carve.lint default rules" do
    subject(:converter) { Jekyll::Carve::Converter.new({ "carve" => { "lint" => true } }) }

    let(:warnings) { [] }

    before do
      allow(Jekyll.logger).to receive(:warn) { |topic, message| warnings << "#{topic} #{message}" }
    end

    # C2-W-156, ruling on carve#6499: rules that only help move from 0.1 are
    # migration notices, off by default, so a valid 0.2 page lints clean.
    it "keeps the thematic-break-spelling migration notice off by default" do
      converter.convert("a\n\n---\n\nb\n")
      expect(warnings).to be_empty
    end

    it "accepts the canonical *** break" do
      converter.convert("a\n\n***\n\nb\n")
      expect(warnings).to be_empty
    end

    it "keeps the deprecated-cell-alignment migration notice off by default" do
      converter.convert("|=< A |\n| a |\n")
      expect(warnings).to be_empty
    end

    it "does not fail a strict build on a migration notice" do
      strict = Jekyll::Carve::Converter.new({ "carve" => { "lint" => "strict" } })
      strict.convert("a\n\n---\n\nb\n")
      expect { strict.check_lint! }.not_to raise_error
    end
  end
end
