# frozen_string_literal: true

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
        ::Carve.to_html(content.to_s, extensions: carve_extensions)
      end

      # Carve extensions configured under `carve.extensions` in _config.yml.
      #
      # Returns an Array of extension names (Strings/Symbols passed through to
      # the engine). Empty when nothing is configured.
      def carve_extensions
        carve_config = @config.is_a?(Hash) ? @config["carve"] : nil
        return [] unless carve_config.is_a?(Hash)

        Array(carve_config["extensions"])
      end
    end
  end
end
