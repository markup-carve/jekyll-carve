# frozen_string_literal: true

require "jekyll-carve"

RSpec.describe Jekyll::Carve::Converter do
  subject(:converter) { described_class.new(config) }

  let(:config) { {} }

  describe "#matches" do
    it "matches the dotted .crv extension" do
      expect(converter.matches(".crv")).to be(true)
    end

    it "matches the bare crv extension" do
      expect(converter.matches("crv")).to be(true)
    end

    it "does not match the .carve extension" do
      expect(converter.matches(".carve")).to be(false)
    end

    it "is case-insensitive" do
      expect(converter.matches(".CRV")).to be(true)
    end

    it "does not match markdown" do
      expect(converter.matches("md")).to be(false)
      expect(converter.matches(".markdown")).to be(false)
    end

    it "does not blow up on nil" do
      expect(converter.matches(nil)).to be(false)
    end
  end

  describe "#output_ext" do
    it "produces an html extension" do
      # Jekyll concatenates this onto the basename, so it includes the dot
      # (".html") to yield index.html. The semantic extension is "html".
      expect(converter.output_ext(".crv")).to eq(".html")
      expect(converter.output_ext(".crv").delete_prefix(".")).to eq("html")
    end
  end

  describe "#convert" do
    it "renders a heading and strong text" do
      html = converter.convert("# Hi *x*")
      expect(html).to include("<h1")
      expect(html).to include("<strong>")
      expect(html).to include("x")
    end

    it "renders a list" do
      html = converter.convert("- one\n- two\n")
      expect(html).to include("<ul>")
      expect(html).to include("<li>")
    end

    context "with configured extensions" do
      let(:config) { { "carve" => { "extensions" => ["math_block"] } } }

      it "reads extensions from Jekyll config" do
        expect(converter.carve_extensions).to eq(["math_block"])
      end

      it "still renders ordinary content" do
        expect(converter.convert("# Title")).to include("<h1")
      end
    end

    context "with no carve config" do
      it "defaults to an empty extension list" do
        expect(converter.carve_extensions).to eq([])
      end
    end
  end
end
