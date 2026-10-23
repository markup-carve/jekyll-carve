# frozen_string_literal: true

require "tmpdir"

require "jekyll-carve"

RSpec.describe "carve.lint" do
  subject(:converter) { Jekyll::Carve::Converter.new(config) }

  let(:carve) { { "lint" => true } }
  let(:config) { { "source" => @root, "carve" => carve } }
  let(:warnings) { [] }

  around do |example|
    Dir.mktmpdir("jekyll-carve-lint") do |dir|
      @root = dir
      example.run
    end
  ensure
    Jekyll::Carve::Rendering.clear
  end

  before do
    allow(Jekyll.logger).to receive(:warn) { |topic, message| warnings << "#{topic} #{message}" }
  end

  def write(relative, body)
    path = File.join(@root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  def render(relative, front_matter, body)
    path = write(relative, "#{front_matter}#{body}")
    Jekyll::Carve::Rendering.with(Struct.new(:path, :relative_path, :site).new(path, relative, nil))
    converter.convert(body)
  ensure
    Jekyll::Carve::Rendering.clear
  end

  it "is off by default" do
    Jekyll::Carve::Converter.new({}).convert("[x](#nope)\n")
    expect(warnings).to be_empty
  end

  it "logs a finding at its line in the file, past the front matter" do
    render("page.crv", "---\ntitle: T\n---\n", "Text.\n\n[x](#nope)\n")
    expect(warnings).to eq([
      "Carve lint: page.crv:6:1: broken-fragment-link: " \
      "Link to \"#nope\" matches no id in this document, so the link goes nowhere.",
    ])
  end

  it "still renders the page" do
    html = render("page.crv", "---\n---\n", "[x](#nope)\n")
    expect(html).to include("<a")
  end

  it "lints with the configured extensions" do
    carve["extensions"] = ["no-such-extension"]
    expect { converter.convert("x\n") }.to raise_error(ArgumentError)
  end

  it "refuses an unknown setting" do
    carve["lint"] = "loud"
    expect { converter.convert("x\n") }.to raise_error(ArgumentError, /carve.lint/)
  end

  describe "with includes" do
    let(:carve) { { "lint" => true, "includes" => true } }

    it "names an included file and its own position" do
      write("part.crv", "é [b](#gone)\n")
      render("index.crv", "---\n---\n", "{{ part.crv }}\n")
      expect(warnings).to include(a_string_starting_with("Carve lint: index.crv (part.crv:1:3): broken-fragment-link"))
    end

    it "does not log an include warning twice" do
      render("index.crv", "---\n---\n", "{{ missing.crv }}\n")
      expect(warnings.grep(/include-unresolved/).size).to eq(1)
    end
  end

  describe "strict" do
    let(:carve) { { "lint" => "strict" } }

    it "fails the build once a finding was counted" do
      converter.convert("[x](#nope)\n")
      expect { converter.check_lint! }.to raise_error(Jekyll::Errors::FatalException, /1 lint finding/)
    end

    it "passes a clean build" do
      converter.convert("# Title\n")
      expect { converter.check_lint! }.not_to raise_error
    end

    it "starts each build from zero" do
      converter.convert("[x](#nope)\n")
      converter.reset_lint
      expect { converter.check_lint! }.not_to raise_error
    end

    it "does not fail a build where lint only warns" do
      warn_only = Jekyll::Carve::Converter.new("carve" => { "lint" => true })
      warn_only.convert("[x](#nope)\n")
      expect { warn_only.check_lint! }.not_to raise_error
    end
  end
end
