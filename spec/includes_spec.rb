# frozen_string_literal: true

require "tmpdir"

require "jekyll-carve"

# Include expansion, contained to a root the site names.
#
# `Jekyll::Converter#convert` sees a String and nothing else, so the page a body
# came from arrives through the `:pre_render` hook. These drive that seam
# directly rather than through a full site build: what is under test is which
# identity and which root reach the engine, not Jekyll's rendering order.
RSpec.describe "Carve includes" do
  subject(:converter) { Jekyll::Carve::Converter.new(config) }

  let(:root) { @root }
  let(:config) do
    { "source" => File.join(@root, "site"),
      "carve" => { "includes" => true } }
  end

  around do |example|
    Dir.mktmpdir("jekyll-carve-inc") do |dir|
      @root = dir
      FileUtils.mkdir_p(File.join(dir, "site", "sub"))
      FileUtils.mkdir_p(File.join(dir, "outside"))
      write("site/sub/frag.crv", "fragment with :crv:\n")
      write("outside/secret.crv", "UNCONTAINED BODY\n")
      example.run
    end
  ensure
    Jekyll::Carve::Rendering.clear
  end

  def write(relative, body)
    path = File.join(@root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  # A stand-in for the Jekyll page the hook hands over: `convert` reads only
  # `path`, `relative_path` and `site` from it.
  def page(relative, body, site: nil)
    path = write(File.join("site", relative), body)
    double = Struct.new(:path, :relative_path, :site)
    double.new(path, relative, site)
  end

  def render(relative, body, site: nil)
    Jekyll::Carve::Rendering.with(page(relative, body, site: site))
    converter.convert(body)
  ensure
    Jekyll::Carve::Rendering.clear
  end

  describe "the switch" do
    it "leaves a directive literal while includes are off" do
      plain = Jekyll::Carve::Converter.new("source" => File.join(root, "site"))
      Jekyll::Carve::Rendering.with(page("index.crv", "{{ sub/frag.crv }}\n"))
      html = plain.convert("{{ sub/frag.crv }}\n")
      expect(html).to include("{{ sub/frag.crv }}")
    end

    it "expands the directive once the site asks" do
      expect(render("index.crv", "{{ sub/frag.crv }}\n")).to include("fragment")
    end

    it "leaves a directive literal when no page is being rendered" do
      html = converter.convert("{{ sub/frag.crv }}\n")
      expect(html).to include("{{ sub/frag.crv }}")
    end
  end

  describe "the root" do
    it "defaults to the site source" do
      expect(converter.include_root).to eq(File.expand_path(File.join(root, "site")))
    end

    it "is nil while the switch is off" do
      plain = Jekyll::Carve::Converter.new("source" => File.join(root, "site"))
      expect(plain.include_root).to be_nil
    end

    it "hands a configured value to the engine as written" do
      config["carve"]["include_root"] = "somewhere"
      expect(converter.include_root).to eq("somewhere")
    end

    it "lets the engine refuse a relative root" do
      config["carve"]["include_root"] = "somewhere"
      expect { render("index.crv", "{{ sub/frag.crv }}\n") }
        .to raise_error(ArgumentError, /absolute/)
    end

    it "widens containment when a root above the source is named" do
      config["carve"]["include_root"] = root
      expect(render("index.crv", "{{ ../outside/secret.crv }}\n"))
        .to include("UNCONTAINED BODY")
    end
  end

  describe "denials" do
    it "does not expand a target outside the root" do
      expect(render("index.crv", "{{ ../outside/secret.crv }}\n"))
        .not_to include("UNCONTAINED BODY")
    end

    it "reports one warning for a refusal and for a missing file alike" do
      messages = capture_warnings do
        render("index.crv", "{{ ../outside/secret.crv }}\n\n{{ nope.crv }}\n")
      end
      expect(messages.length).to eq(2)
      expect(messages).to all(include("include-unresolved"))
    end

    it "keeps the denial class off the page warning" do
      messages = capture_warnings { render("index.crv", "{{ ../outside/secret.crv }}\n") }
      expect(messages.join).not_to include("outside-root")
    end

    it "still reports the denial class for the build log" do
      messages = capture_debug do
        render("index.crv", "{{ ../outside/secret.crv }}\n\n{{ nope.crv }}\n")
      end
      expect(messages.join).to include("outside-root")
      expect(messages.join).to include("not-found")
    end

    it "names the page that asked" do
      messages = capture_warnings { render("guide.crv", "{{ nope.crv }}\n") }
      expect(messages.first).to include("guide.crv")
      expect(messages.first).to include("include-unresolved")
    end

    it "reports no host path" do
      messages = capture_warnings { render("sub/page.crv", "{{ nope.crv }}\n") }
      expect(messages.join).not_to include(root)
    end
  end

  describe "what the engine is asked to do" do
    it "resolves a path against the page that wrote it" do
      expect(render("sub/page.crv", "{{ frag.crv }}\n")).to include("fragment")
    end

    it "resolves a nested path against the including file" do
      write("site/sub/deep/inner.crv", "inner text\n")
      write("site/sub/frag.crv", "{{ deep/inner.crv }}\n")
      expect(render("index.crv", "{{ sub/frag.crv }}\n")).to include("inner text")
    end

    it "degrades a cycle instead of hanging" do
      write("site/a.crv", "A {{ b.crv }}\n")
      write("site/b.crv", "B {{ a.crv }}\n")
      messages = capture_warnings { @html = render("index.crv", "{{ a.crv }}\n") }
      expect(@html).to include("A B")
      expect(messages.join).to include("include-cycle")
    end

    it "carries the symbol map into an included child" do
      config["carve"]["symbols"] = { "crv" => "CARVE" }
      html = render("index.crv", "{{ sub/frag.crv }}\n")
      expect(html).to include("CARVE")
      expect(html).not_to include(":crv:")
    end

    it "carries the extension set into an included child" do
      write("site/sub/frag.crv", "# Child\n")
      config["carve"]["extensions"] = ["heading_permalinks"]
      expect(render("index.crv", "{{ sub/frag.crv }}\n")).to include("permalink")
    end
  end

  describe "regeneration" do
    let(:regenerator) { FakeRegenerator.new }
    let(:site) { Struct.new(:regenerator).new(regenerator) }

    it "records a resolved target against the page" do
      document = page("index.crv", "{{ sub/frag.crv }}\n", site: site)
      Jekyll::Carve::Rendering.with(document)
      converter.convert("{{ sub/frag.crv }}\n")
      expect(regenerator.recorded).to eq(
        [[document.path, File.join(File.expand_path(File.join(root, "site")), "sub/frag.crv")]]
      )
    end

    it "records nothing for a target it could not read" do
      document = page("index.crv", "{{ nope.crv }}\n", site: site)
      Jekyll::Carve::Rendering.with(document)
      capture_warnings { converter.convert("{{ nope.crv }}\n") }
      expect(regenerator.recorded).to be_empty
    end
  end

  class FakeRegenerator
    attr_reader :recorded

    def initialize
      @recorded = []
    end

    def add_dependency(path, target)
      @recorded << [path, target]
    end
  end

  def capture_warnings(&block)
    capture_log(:warn, &block)
  end

  def capture_debug(&block)
    capture_log(:debug, &block)
  end

  # Jekyll's logger writes through a writer object; replacing it is what makes
  # one level readable on its own. Driving each level separately keeps a
  # message that landed at the wrong one from counting.
  def capture_log(level)
    captured = []
    writer = Jekyll.logger.writer
    recorder = Object.new
    recorder.define_singleton_method(:level) { 0 }
    recorder.define_singleton_method(:level=) { |_| }
    %i[debug info warn error].each do |name|
      recorder.define_singleton_method(name) do |message|
        captured << message if name == level
      end
    end
    previous = Jekyll.logger.level
    Jekyll.logger.instance_variable_set(:@writer, recorder)
    Jekyll.logger.log_level = :debug
    yield
    captured
  ensure
    Jekyll.logger.instance_variable_set(:@writer, writer)
    Jekyll.logger.log_level = previous
  end
end
