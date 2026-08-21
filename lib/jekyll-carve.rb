# frozen_string_literal: true

require "json"

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
        ::Carve.to_html(content.to_s,
                        extensions: carve_extensions,
                        symbols: carve_symbols)
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
        signature = symbol_source_signature
        unless @symbol_signature == signature
          @symbols = build_symbols
          @symbol_signature = signature
        end
        @symbols
      end

      private

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

      # One configured path, resolved and clamped inside the site source.
      #
      # `Jekyll.sanitized_path` is what does the clamping: "../../etc/passwd"
      # resolves to "<source>/etc/passwd", so a path cannot name a file outside
      # the project even by accident.
      def symbol_path(relative_path)
        Jekyll.sanitized_path(site_source, relative_path)
      end

      # Absolute paths for the file-shaped sources, in configuration order.
      def symbol_paths
        symbol_sources.grep(String).map { |path| symbol_path(path) }
      end

      # What the cached map was built from, so an edit invalidates it.
      #
      # Jekyll calls `setup` (which instantiates converters) from
      # `Site#initialize`, while `Site#process` calls only `reset`. So under
      # `jekyll serve --watch` ONE converter instance serves every rebuild, and
      # a plain memo would keep serving a map built from a file the author has
      # since edited. Keying the memo on each file's mtime and size costs one
      # stat per configured path and keeps the parse itself once per build.
      def symbol_source_signature
        symbol_paths.map do |path|
          stat = File.stat(path)
          [path, stat.mtime, stat.size]
        rescue SystemCallError
          [path, :unreadable]
        end
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

      # Coerce one source's keys and values to the Strings the engine takes.
      #
      # These are Hash keys of a shortcode map, NOT Ruby Symbols - `carve.symbols`
      # and the `Strings/Symbols passed through` of `carve_extensions` are
      # different things that share a word.
      #
      # A nested Hash or Array is refused rather than stringified: the value goes
      # into the page RAW, and `{"a"=>"b"}` appearing in the output is nobody's
      # intent.
      def normalize_symbols(map, origin)
        map.each_with_object({}) do |(name, value), out|
          case value
          when nil, Hash, Array
            raise ArgumentError,
                  "#{origin}: the value for #{name.to_s.inspect} must be a string, " \
                  "got #{value.class}"
          else
            out[name.to_s] = value.to_s
          end
        end
      end
    end
  end
end
