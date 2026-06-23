# frozen_string_literal: true

# Fallback loader so the example site builds even when the plugin is not
# installed as a gem. When jekyll-carve is installed normally (Gemfile or
# `plugins:` in _config.yml) this require is harmless / already satisfied.
require "jekyll-carve"
