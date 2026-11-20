# frozen_string_literal: true

require "json"
require "pathname"

require "jekyll"
require "carve"

require "jekyll/carve/version"

module Jekyll
  module Carve
    # Jekyll converter for the Carve markup language.
    #
    # Registers the `.crv` file extension and renders Carve
    # bodies to HTML by delegating to the native `carve-lang` gem
    # (Carve.to_html). No parsing is reimplemented here; this is a thin
    # Jekyll::Converter adapter over the engine.
    class Converter < Jekyll::Converter
      # File extensions this converter handles (lowercased, with and without
      # the leading dot so callers may pass either form).
      EXTENSIONS = %w[.crv].freeze

      safe true
      priority :low

      # Does the given file extension belong to Carve?
      #
      # Accepts both ".crv" and "crv" (Jekyll passes the dotted form).
      #
      # ext - The String extension to check.
      #
      # Returns true if it matches, false otherwise.
      def matches(ext)
        return false if ext.nil?

        normalized = ext.to_s.downcase
        normalized = ".#{normalized}" unless normalized.start_with?(".")
        EXTENSIONS.include?(normalized)
      end

      # The output extension for a converted Carve file.
      #
      # Jekyll appends this string directly to the output path
      # (":basename:output_ext"), so it MUST include the leading dot to
      # produce "index.html" rather than "indexhtml". This matches Jekyll's
      # own Markdown converter, which returns ".html".
      #
      # Returns ".html".
      def output_ext(_ext)
        ".html"
      end

      # Convert a Carve document body to HTML.
      #
      # Jekyll strips the YAML front matter before calling this, so `content`
      # is the Carve body only.
      #
      # content - String body of the source file (front matter removed).
      #
      # Returns the rendered HTML String.
      def convert(content)
        require_carve_02!
        document = Rendering.current
        root = include_root
        include_page = !(root.nil? || document.nil? || document.path.to_s.empty?)
        html = render(content.to_s, document, include_page ? root : nil)
        lint(content.to_s, document, include_page ? root : nil) if lint_mode
        html
      end

      # How `carve.lint` is set: nil (off), :warn or :strict.
      #
      # `true` logs each finding as a build warning; `"strict"` also fails the
      # build once every page has been linted.
      def lint_mode
        case (value = carve_config["lint"])
        when nil, false then nil
        when true then :warn
        when "strict", :strict then :strict
        else
          raise ArgumentError,
                "carve.lint: expected true, false or \"strict\", got #{value.inspect}"
        end
      end

      # Lint findings counted under `carve.lint: strict` since the last reset.
      def lint_findings
        @lint_findings ||= 0
      end

      # Fail the build when strict lint counted a finding.
      #
      # Called from the `:site, :post_render` hook below, so every page is
      # linted and reported before the build stops.
      def check_lint!
        return unless lint_mode == :strict && lint_findings.positive?

        raise Jekyll::Errors::FatalException,
              "carve.lint: #{lint_findings} lint finding(s) under strict mode; see the warnings above"
      end

      # Drop the strict-mode count, so each build is judged on its own.
      def reset_lint
        @lint_findings = 0
      end

      # The containment root configured under `carve.include_root`, or nil when
      # `carve.includes` is off.
      #
      # A configured value is handed to the engine exactly as written. The
      # engine refuses a relative root, and that refusal is what keeps
      # containment off whatever directory the build ran from; expanding it
      # here would mean it never fires. The default is Jekyll's own source
      # directory, which this package derives rather than reads, so that one is
      # expanded.
      def include_root
        return nil unless carve_config["includes"]

        configured = carve_config["include_root"]
        return configured.to_s if configured.is_a?(String) && !configured.empty?

        File.expand_path(site_source)
      end

      # Carve extensions configured under `carve.extensions` in _config.yml.
      #
      # Returns an Array of extension names (Strings/Symbols passed through to
      # the engine). Empty when nothing is configured.
      def carve_extensions
        Array(carve_config["extensions"])
      end

      # The `:name:` symbol map configured under `carve.symbols` in _config.yml.
      #
      # Carve parses `:name:` in core, but what a name renders as is a render
      # option, so a document reaching the engine without a map renders the
      # shortcode as its own source text.
      #
      # The key accepts three shapes:
      #
      #   carve:
      #     symbols:                    # a mapping, written inline
      #       smile: "😄"
      #
      #   carve:
      #     symbols: _data/symbols.json # a path to a JSON object
      #
      #   carve:
      #     symbols:                    # both, merged left to right
      #       - _data/emoji.json
      #       - { ship: "🚀" }
      #
      # A path is resolved against the site source and clamped inside it, so it
      # names a file in the project and never one outside it.
      #
      # SECURITY: the engine substitutes a symbol value as TRUSTED RAW output -
      # it is NOT escaped, so `{ "l" => "<img src='/l.svg'>" }` emits a real
      # element. carve-rb states the rule this inherits: "NEVER build a symbols
      # map out of untrusted / user-supplied input." That is why the only
      # inputs here are _config.yml and files at paths named in it. Page
      # content and front matter cannot reach this method - `convert` ignores
      # its argument when building the map, and Jekyll hands a converter no
      # front matter at all.
      #
      # Returns a Hash of String name => String value, or nil when nothing is
      # configured (nil, so the engine keeps its own default rather than being
      # told there are no symbols).
      def carve_symbols
        return @symbols if defined?(@symbols)

        @symbols = build_symbols
      end

      # Drop the cached map, so the next render resolves it again.
      #
      # Called from the `:site, :after_reset` hook at the bottom of this file,
      # which is what makes the map resolve once per BUILD rather than once per
      # process. Jekyll instantiates converters from `Site#initialize` while
      # `Site#process` calls only `reset`, so under `jekyll serve --watch` ONE
      # converter instance serves every rebuild - and a map memoized outright
      # would keep serving a file the author has since edited.
      #
      # Returns nothing.
      def reset_symbols
        remove_instance_variable(:@symbols) if defined?(@symbols)
      end

      # `carve.raw_html: true` emits `=html` blocks and spans verbatim. Carve
      # 0.2 escapes them by default.
      def raw_html?
        carve_config["raw_html"] == true
      end

      private

      # The gemspec range cannot tell the unreleased 0.2 binding from 0.1.x (both
      # report 0.1.x), so the 0.2 API is checked by its `Carve.call` entry point.
      def require_carve_02!
        return if ::Carve.respond_to?(:call)

        raise ArgumentError,
              "jekyll-carve needs the Carve 0.2 carve-lang (carve-rb next2); " \
              "the installed carve-lang #{::Carve::VERSION} is a 0.1 engine"
      end

      # The Carve 0.2 standard extensions each 0.1 extension name stands for. A
      # name missing here and not starting with `carve.` reaches the engine as
      # written.
      LEGACY_EXTENSIONS = {
        "citations" => ["carve.references"],
        "code-callouts" => ["carve.codeCallouts"],
        "code-group" => ["carve.codeGroup"],
        "color-swatch" => ["carve.colorSwatch"],
        "details" => ["carve.details"],
        "fenced-render" => ["carve.fencedRender.mermaid"],
        "fenced-render-abc" => ["carve.fencedRender.abc"],
        "fenced-render-chart" => ["carve.fencedRender.chart"],
        "fenced-render-d2" => ["carve.fencedRender.d2"],
        "fenced-render-graphviz" => ["carve.fencedRender.graphviz"],
        "fenced-render-plantuml" => ["carve.fencedRender.plantuml"],
        "fenced-render-vega-lite" => ["carve.fencedRender.vega-lite"],
        "fenced-render-wavedrom" => ["carve.fencedRender.wavedrom"],
        "glossary" => ["carve.glossary"],
        "img-fence" => ["carve.imgFence.img", "carve.imgFence.image"],
        "index" => ["carve.index"],
        "list-table" => ["carve.listTable"],
        "math-block" => ["carve.mathBlock"],
        "semantic-span" => ["carve.semanticSpan"],
        "smart-quotes" => ["carve.smartQuotes"],
        "spoiler" => ["carve.spoiler", "carve.spoilerBlock"],
        "tab-normalize" => ["carve.tabNormalize"],
        "tabs" => ["carve.tabs"],
        "wikilinks" => ["carve.wiki"],
      }.freeze

      # 0.1 extensions the 0.2 engine does not have yet.
      PENDING_EXTENSIONS = %w[
        autolink external-links heading-level-shift heading-numbers
        heading-permalinks heading-reference table-of-contents toc
      ].freeze

      # Standard extensions without a standard renderer in the engine.
      NO_STANDARD_RENDERER = %w[carve.cite].freeze

      # The 0.2 standard extension names for `carve.extensions`, or nil when the
      # site configured none. 0.1 names are accepted in either spelling.
      def engine_extensions
        names = carve_extensions.flat_map do |entry|
          name = entry.to_s
          next [name] if name.start_with?("carve.")

          key = name.tr("_", "-")
          if PENDING_EXTENSIONS.include?(key)
            raise ArgumentError,
                  "carve.extensions: #{name} is not a standard extension of the 0.2 engine yet " \
                  "(markup-carve/carve-rs#4476)"
          end
          LEGACY_EXTENSIONS.fetch(key, [name])
        end.uniq
        names.empty? ? nil : names
      end

      # The standard renderer for each enabled extension that has one.
      def engine_renderers(names)
        return nil if names.nil?

        names.reject { |name| NO_STANDARD_RENDERER.include?(name) }.to_h { |name| [name, "standard"] }
      end

      def render(content, document, root)
        extensions = engine_extensions
        if root.nil?
          return ::Carve.to_html(content,
                                 extensions: extensions,
                                 renderers: engine_renderers(extensions),
                                 symbols: carve_symbols,
                                 raw_html: raw_html?)
        end

        unless ::Carve.respond_to?(:to_html_with_includes)
          raise ArgumentError, "carve.includes: the installed carve-lang is too old; upgrade it to 0.1.4 or later"
        end

        begin
          result = ::Carve.to_html_with_includes(content,
                                                 root: root,
                                                 source_path: document.path,
                                                 extensions: extensions,
                                                 renderers: engine_renderers(extensions),
                                                 symbols: carve_symbols,
                                                 raw_html: raw_html?)
        rescue ArgumentError => e
          # A relative root, or a page outside it. Both are decided by the
          # engine; what this adds is the key and the page to look at.
          raise ArgumentError,
                "carve.include_root: #{document.relative_path || document.path}: #{e.message}"
        end
        report_includes(result, document, root)
        result[:value]
      end

      # Log each lint finding as a build warning, located in the source file.
      #
      # Runs after rendering, so a bad include root is reported by the render
      # path with its own message. With includes on, the include-* findings
      # repeat the include warnings `report_includes` already logged, so they
      # are counted but not logged twice.
      def lint(content, document, root)
        page = document && (document.relative_path || document.path).to_s
        page = "(no page)" if page.nil? || page.empty?
        # 0.2 lint reads no extensions (C2-W-109).
        options = {}
        options.update(root: root, source_path: document.path) if root
        findings = ::Carve.lint(content, **options)
        offset = front_matter_lines(document)
        own = root && Pathname.new(document.path.to_s).relative_path_from(Pathname.new(root)).to_s
        findings.each do |finding|
          next if root && finding[:code].start_with?("include-")

          origin = finding[:file]
          origin = nil if origin == own
          text = origin ? File.read(File.join(root, origin), encoding: "utf-8") : content
          line, column = position(text, finding.dig(:range, :startOffset).to_i)
          where = if origin
                    "#{page} (#{origin}:#{line}:#{column})"
                  else
                    "#{page}:#{line + offset}:#{column}"
                  end
          Jekyll.logger.warn "Carve lint:", "#{where}: #{finding[:code]}: #{finding[:message]}"
        end
        @lint_findings = lint_findings + findings.size if lint_mode == :strict
      end

      # A 1-based line and character column for a UTF-8 byte offset in text.
      def position(text, offset)
        before = text.b[0, [offset, 0].max].force_encoding("utf-8").scrub("")
        [before.count("\n") + 1, before.length - (before.rindex("\n") || -1)]
      end

      # Lines of YAML front matter above the body, so a finding names the line
      # in the file. Jekyll strips the front matter before `convert` sees it.
      def front_matter_lines(document)
        path = document&.path.to_s
        return 0 if path.empty? || !File.file?(path)

        match = Jekyll::Document::YAML_FRONT_MATTER_REGEXP.match(File.read(path, encoding: "bom|utf-8"))
        match ? match[0].count("\n") : 0
      end

      # Surface what expansion degraded, and record what it read.
      #
      # Carve 0.2 names the cause in the code (C2-N-061), so a missing file
      # and a containment refusal are told apart by the warning itself.
      def report_includes(result, document, root)
        page = document.relative_path || document.path
        Array(result[:warnings]).each do |warning|
          next unless warning[:code].to_s.start_with?("include-") && warning[:channel] == "parse"

          origin = warning[:file]
          where = origin && origin != page ? "#{page} (#{origin})" : page
          Jekyll.logger.warn "Carve:", "#{where}: #{warning[:code]}: #{warning[:message]}"
        end
        suppressed = result[:suppressedWarnings].to_i
        if suppressed.positive?
          Jekyll.logger.warn "Carve:",
                             "#{page}: #{suppressed} further include warnings suppressed"
        end
        Array(result[:dependencies]).each do |dependency|
          next unless dependency[:read] && dependency[:file]

          register_dependency(document, File.join(root, dependency[:file].to_s))
        end
      end

      # Tell Jekyll the page has to be rebuilt when this target changes.
      #
      # Only a RESOLVED target is registered. An unresolved dependency reports
      # the directive as written rather than a path relative to the root, so
      # joining it onto the root names the wrong file: a nested `missing.crv`
      # would be recorded against the root rather than against the directory
      # its parent sits in. A fragment appearing later is covered by Jekyll's
      # own watch over the source directory.
      def register_dependency(document, target)
        regenerator = document.site&.regenerator
        return unless regenerator.respond_to?(:add_dependency)

        regenerator.add_dependency(document.path, target)
      end

      # The `carve` table from _config.yml, or an empty Hash.
      def carve_config
        config = @config.is_a?(Hash) ? @config["carve"] : nil
        config.is_a?(Hash) ? config : {}
      end

      # The configured symbol sources, always as an Array.
      #
      # NOT `Array(value)`: a Hash passed to Kernel#Array comes back as an
      # array of PAIRS ({"a" => "b"} becomes [["a", "b"]]), which would silently
      # shred an inline mapping into something that is no longer a map.
      def symbol_sources
        value = carve_config["symbols"]
        case value
        when nil   then []
        when Array then value
        else            [value]
        end
      end

      # The site source directory a symbol path is resolved against.
      def site_source
        source = @config.is_a?(Hash) ? @config["source"].to_s : ""
        source.empty? ? Dir.pwd : source
      end

      # One configured path, resolved and confined to the site source.
      #
      # Two layers, because they stop different things.
      #
      # `Jekyll.sanitized_path` clamps the LEXICAL path: "../../etc/passwd"
      # comes back as "<source>/etc/passwd", so a written path cannot name a
      # file outside the project.
      #
      # A symlink is not lexical. A link INSIDE the source pointing at a file
      # outside it survives that clamp, and `File.read` follows it - which on a
      # host building a site it did not write would read and potentially
      # publish that file, through a converter that declares `safe true`. So
      # the resolved path is compared against the site source with both sides
      # fully resolved. Jekyll takes the same posture in safe mode: its reader
      # excludes symlinked entries outright.
      def symbol_path(relative_path)
        path = Jekyll.sanitized_path(site_source, relative_path)
        real, root = begin
          [File.realpath(path), File.realpath(site_source)]
        rescue SystemCallError
          # Nothing there to resolve. load_symbol_file raises naming the path.
          return path
        end
        return real if real == root || real.start_with?(root + File::SEPARATOR)

        raise ArgumentError,
              "carve.symbols: #{relative_path} resolves to #{real}, which is " \
              "outside the site source #{root}"
      end

      # Merge every configured source, left to right, into one map.
      def build_symbols
        merged = symbol_sources.each_with_object({}) do |source, out|
          case source
          when Hash   then out.merge!(normalize_symbols(source, "carve.symbols"))
          when String then out.merge!(load_symbol_file(source))
          else
            raise ArgumentError,
                  "carve.symbols: expected a mapping or a path to a JSON file, " \
                  "got #{source.class}"
          end
        end
        merged.empty? ? nil : merged
      end

      # Read one JSON file named by carve.symbols.
      #
      # A misconfigured map is raised rather than warned past: every page loses
      # every symbol, and a build that renders `:smile:` as text with a line in
      # the log is the version of this that costs an afternoon.
      def load_symbol_file(relative_path)
        path = symbol_path(relative_path)
        raise ArgumentError, "carve.symbols: no such file: #{path}" unless File.file?(path)

        begin
          parsed = JSON.parse(File.read(path))
        rescue JSON::ParserError => e
          raise ArgumentError, "carve.symbols: #{path} is not valid JSON: #{e.message}"
        end
        unless parsed.is_a?(Hash)
          raise ArgumentError,
                "carve.symbols: #{path} must hold a JSON object mapping a name " \
                "to its value, got #{parsed.class}"
        end

        normalize_symbols(parsed, path)
      end

      # Check one source and key it by String name.
      #
      # These are Hash keys of a shortcode map, NOT Ruby Symbols - `carve.symbols`
      # and the `Strings/Symbols passed through` of `carve_extensions` are
      # different things that share a word. A name IS coerced, because YAML
      # hands back a Symbol or a boolean for some unquoted keys (`:on:` is a
      # perfectly ordinary shortcode to want) and a name never reaches output.
      #
      # A VALUE is not coerced. It goes into the page RAW, so `count: 1` or a
      # nested mapping is a mistake worth stopping the build for rather than
      # something to stringify and emit. The engine draws the same line: it
      # raises TypeError on a non-String value.
      def normalize_symbols(map, origin)
        map.each_with_object({}) do |(name, value), out|
          unless value.is_a?(String)
            raise ArgumentError,
                  "#{origin}: the value for #{name.to_s.inspect} must be a string, " \
                  "got #{value.class}"
          end

          out[name.to_s] = value
        end
      end
    end

    # Which document Jekyll is rendering right now.
    #
    # `Jekyll::Converter#convert` is handed a String and nothing else, so a
    # converter cannot see the file the body came from - and an include has to
    # resolve against that file. The `:pre_render` hook carries it, and Jekyll
    # renders documents one at a time, so the current one is a thread-local
    # rather than a queue.
    module Rendering
      KEY = :jekyll_carve_document

      module_function

      def current
        Thread.current[KEY]
      end

      def with(document)
        Thread.current[KEY] = document
      end

      def clear
        Thread.current[KEY] = nil
      end
    end
  end
end

Jekyll::Hooks.register %i[pages documents], :pre_render do |document|
  Jekyll::Carve::Rendering.with(document)
end

Jekyll::Hooks.register %i[pages documents], :post_render do |_document|
  Jekyll::Carve::Rendering.clear
end

# Resolve the symbol map once per build rather than once per process.
#
# `Site#reset` runs at the top of every `Site#process`, including every rebuild
# under `jekyll serve --watch`, and it is the only site event that fires on a
# rebuild without also re-instantiating the converters. See
# Jekyll::Carve::Converter#reset_symbols.
#
# `converters` is nil the first time this fires: `Site#initialize` calls `reset`
# BEFORE `setup`, and `setup` is what builds the converter list.
Jekyll::Hooks.register :site, :after_reset do |site|
  Array(site.converters).each do |converter|
    next unless converter.is_a?(Jekyll::Carve::Converter)

    converter.reset_symbols
    converter.reset_lint
  end
end

# `carve.lint: strict` fails here, after every page was linted and before any
# output is written.
Jekyll::Hooks.register :site, :post_render do |site|
  Array(site.converters).each do |converter|
    converter.check_lint! if converter.is_a?(Jekyll::Carve::Converter)
  end
end
