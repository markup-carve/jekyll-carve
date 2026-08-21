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

  # `:name:` is core Carve syntax, but what a name renders AS is a render
  # option. Without a map the engine renders the shortcode as its own source
  # text, which is correct and is also what a site configuring one does not
  # want. See jekyll-carve#7.
  describe "#carve_symbols" do
    let(:fixtures) { File.expand_path("fixtures", __dir__) }

    context "with no carve.symbols key" do
      it "passes no map, so the engine keeps its own default" do
        expect(converter.carve_symbols).to be_nil
      end

      it "leaves a shortcode as literal text" do
        expect(converter.convert("Ship it :smile:")).to include(":smile:")
      end
    end

    context "with an inline mapping" do
      let(:config) { { "carve" => { "symbols" => { "smile" => "\u{1F604}" } } } }

      it "reads the map from Jekyll config" do
        expect(converter.carve_symbols).to eq({ "smile" => "\u{1F604}" })
      end

      it "renders the mapped name" do
        expect(converter.convert("Ship it :smile:")).to include("\u{1F604}")
      end

      it "leaves an unmapped name literal beside a mapped one" do
        html = converter.convert("Ship it :smile: :shrug:")
        expect(html).to include("\u{1F604}")
        expect(html).to include(":shrug:")
      end

      # A configured map must not loosen the engine's word-boundary guard: a
      # shortcode needs a boundary before its opening colon, so a time, a
      # ratio and a code span are not shortcodes even when the name is mapped.
      it "still requires a word boundary before the opening colon" do
        expect(converter.convert("a:smile:b")).to include("a:smile:b")
        expect(converter.convert("3:smile:4")).to include("3:smile:4")
        expect(converter.convert("`:smile:`")).to include(":smile:")
        expect(converter.convert("`:smile:`")).not_to include("\u{1F604}")
      end

      it "does substitute where the boundary is there" do
        expect(converter.convert("A :smile: here")).to include("\u{1F604}")
      end

      # Kernel#Array turns a Hash into an array of pairs, which would shred an
      # inline mapping into something that is no longer a map.
      it "does not flatten the mapping into pairs" do
        expect(converter.carve_symbols).to be_a(Hash)
      end
    end

    context "with a path to a JSON file" do
      let(:config) { { "source" => fixtures, "carve" => { "symbols" => "symbols.json" } } }

      it "resolves the file relative to the site source" do
        expect(converter.carve_symbols).to eq({ "smile" => "\u{1F604}", "ship" => "\u{1F680}" })
      end

      it "renders a name from the file" do
        expect(converter.convert("Ship it :ship:")).to include("\u{1F680}")
      end

      it "parses the file once and reuses the map" do
        expect(File).to receive(:read).once.and_call_original
        3.times { converter.carve_symbols }
      end
    end

    context "with a list of sources" do
      let(:config) do
        {
          "source" => fixtures,
          "carve"  => { "symbols" => ["symbols.json", { "ship" => "SHIP" }] },
        }
      end

      it "merges left to right, so a later source overrides an earlier one" do
        expect(converter.carve_symbols).to eq({ "smile" => "\u{1F604}", "ship" => "SHIP" })
      end
    end

    # The map is substituted RAW by the engine, so where it may come from is
    # the whole of the security story: _config.yml, and files at paths named
    # in it, clamped inside the site source.
    context "with a path that tries to leave the site source" do
      let(:config) do
        { "source" => fixtures, "carve" => { "symbols" => "../../../../etc/passwd" } }
      end

      it "clamps the path inside the source instead of following it" do
        expect { converter.carve_symbols }
          .to raise_error(ArgumentError, %r{#{Regexp.escape(fixtures)}/etc/passwd})
      end
    end

    context "with a misconfigured map" do
      def converter_for(symbols)
        described_class.new({ "source" => fixtures, "carve" => { "symbols" => symbols } })
      end

      it "raises when the file does not exist" do
        expect { converter_for("nope.json").carve_symbols }
          .to raise_error(ArgumentError, /no such file/)
      end

      it "raises when the file is not valid JSON" do
        expect { converter_for("broken.json").carve_symbols }
          .to raise_error(ArgumentError, /not valid JSON/)
      end

      it "raises when the JSON top level is not an object" do
        expect { converter_for("not-an-object.json").carve_symbols }
          .to raise_error(ArgumentError, /must hold a JSON object/)
      end

      # A nested Hash would otherwise be stringified into the page RAW.
      it "raises on a value that is not a string" do
        expect { converter_for({ "smile" => { "nested" => "x" } }).carve_symbols }
          .to raise_error(ArgumentError, /value for "smile" must be a string/)
      end

      it "raises on a source that is neither a mapping nor a path" do
        expect { converter_for([42]).carve_symbols }
          .to raise_error(ArgumentError, /expected a mapping or a path/)
      end
    end
  end
end
