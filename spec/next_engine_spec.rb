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

    it "still render as alignment" do
      expect(render(source)).to include(%(style="text-align: right;">B</th>))
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

    it "reports a --- thematic break as thematic-break-spelling" do
      converter.convert("a\n\n---\n\nb\n")
      expect(warnings.join("\n")).to include("thematic-break-spelling")
    end

    it "accepts the canonical *** break" do
      converter.convert("a\n\n***\n\nb\n")
      expect(warnings).to be_empty
    end

    it "reports a glued alignment marker as deprecated-cell-alignment" do
      converter.convert("|=< A |\n| a |\n")
      expect(warnings.join("\n")).to include("deprecated-cell-alignment")
    end

    it "fails a strict build on the new rule" do
      strict = Jekyll::Carve::Converter.new({ "carve" => { "lint" => "strict" } })
      strict.convert("a\n\n---\n\nb\n")
      expect { strict.check_lint! }.to raise_error(Jekyll::Errors::FatalException)
    end
  end
end
