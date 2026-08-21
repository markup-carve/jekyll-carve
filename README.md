# jekyll-carve

A [Jekyll](https://jekyllrb.com) converter plugin for the
[Carve](https://github.com/markup-carve/carve) markup language. It renders
`.crv` pages to HTML by delegating to the native
[`carve-lang`](https://github.com/markup-carve/carve-rb) gem (`Carve.to_html`). No
parser is reimplemented here; this is a thin `Jekyll::Converter` adapter over
the engine.

## Install

Add both gems to your site's `Gemfile`:

```ruby
# Gemfile
gem "jekyll-carve"
gem "carve-lang" # the native Carve engine (a runtime dependency, listed for clarity)
```

```sh
bundle install
```

Then enable the plugin in `_config.yml`:

```yaml
plugins:
  - jekyll-carve
```

> [!NOTE]
> The `carve-lang` gem ships a Rust native extension and is compiled at install
> time. It requires a Rust toolchain (`cargo`) and Ruby development headers.
> See the carve-rb README for build notes (including the libclang/`stdarg.h`
> workaround on some systems).

## Configuration

Carve engine options are read from `_config.yml` under the `carve` key:

```yaml
carve:
  extensions:
    - heading_permalinks
    - math_block
    - autolink
```

`carve.extensions` is an array of opt-in Carve extension names (Strings or
hyphenated/underscored forms, passed straight through to the engine). When the
key is absent, no extensions are enabled. The recognized extensions are listed
in `Carve::EXTENSIONS`; an unknown name raises `ArgumentError` at build time.

### `carve.symbols` - what `:smile:` renders as

Carve parses `:name:` in core, no extension needed, but what a name renders as
is a render option. With no map configured a shortcode renders as its own
source text:

```text
Ship it :smile:
```

```html
<p>Ship it :smile:</p>
```

`carve.symbols` supplies the map. It takes a mapping written inline:

```yaml
carve:
  symbols:
    smile: "😄"
    ship: "🚀"
```

or a path to a JSON object, so a large map does not have to live in
`_config.yml`:

```yaml
carve:
  symbols: _data/symbols.json
```

```json
{
  "smile": "😄",
  "ship": "🚀"
}
```

or a list mixing both, merged left to right, so a generated map can carry a few
site-specific overrides:

```yaml
carve:
  symbols:
    - _data/emoji.json
    - ship: "🚀"
```

A path is resolved against the site source and confined to it, symlinks
included - a link inside the source pointing at a file outside it is refused
rather than followed. A name that
is not in the map keeps rendering as its own text, and the map does not loosen
Carve's word-boundary rule: `10:30:` and `a:smile:b` are not shortcodes, and
`` `:smile:` `` inside a code span stays code.

No emoji table ships with this plugin. Jekyll has no emoji database in core, so
bundling one here would be a second source of truth next to whatever your
Markdown pages already use (`jemoji`, for instance) - and the two would drift.
Point `carve.symbols` at a JSON file you generate from that same source and
both page types resolve one map.

A misconfigured map fails the build rather than being warned past: a missing
file, invalid JSON, a JSON top level that is not an object, or a value that is
not a string each raise `ArgumentError` naming the file or the key. A value is
not coerced, because it reaches the page raw - `count: 1` is a mistake worth
stopping for, not something to stringify and emit. A NAME is coerced, since
YAML hands back a Symbol or a boolean for some unquoted keys and a name never
reaches the output.

> [!WARNING]
> A symbol value is inserted as **trusted raw output**. It is not escaped, so
> `smile: "<img src='/s.svg'>"` emits a real `<img>` element rather than
> escaped text. This is deliberate in the engine - `carve-lang` documents it as
> "NEVER build a symbols map out of untrusted / user-supplied input" - and it
> is why this plugin reads the map only from `_config.yml` and from files at
> paths named there. Never generate `carve.symbols` from page content, from
> front matter, from a comment system, or from anything else a visitor can
> influence.

## Usage

Create a page with a `.crv` extension. It MUST begin with Jekyll
YAML front matter, and the Carve body follows below:

```text
---
layout: default
title: Home
---
# Welcome to *Carve*

This is /italic/ and *bold* text.

- Apple
- Banana
```

Note Carve's inline syntax: `*...*` is **strong** (bold) and `/.../` is
_emphasis_ (italic) - the opposite of Markdown.

## Important: Jekyll front matter vs. Carve frontmatter

This is the one nuance to understand:

- **Jekyll only runs a file through a converter if it has YAML front matter**
  (a `---` ... `---` block at the very top). A `.crv` file with no front
  matter is treated as a static file and copied verbatim, NOT converted.
- **Jekyll strips that front matter before calling the converter.** So the
  converter (and therefore the Carve engine) receives only the document
  **body**, never the Jekyll front matter.
- **Carve itself also uses `---` for its own frontmatter.** In a Jekyll site
  the Jekyll front matter wins: the top `---` ... `---` block is consumed by
  Jekyll, and whatever remains is handed to Carve as the body.

Practical rule: a `.crv` page in Jekyll needs at least an empty front matter
block so Jekyll processes it:

```text
---
---
# Your Carve content here
```

Put page metadata (`title`, `layout`, etc.) in the Jekyll front matter. Do not
add a second Carve `---` frontmatter block expecting Carve to parse it; Jekyll
has already removed the leading block by the time Carve runs.

## Converter API

`Jekyll::Carve::Converter < Jekyll::Converter`:

| Method | Behavior |
| ------ | -------- |
| `matches(ext)` | `true` for `.crv` (with or without the leading dot, case-insensitive), `false` otherwise. |
| `output_ext(ext)` | `".html"` (includes the dot so Jekyll emits `page.html`). |
| `convert(content)` | `Carve.to_html(content, extensions: configured, symbols: configured)` - the rendered HTML. |
| `carve_extensions` | The extension list read from `carve.extensions` in `_config.yml` (empty by default). |
| `carve_symbols` | The `:name:` map read from `carve.symbols` in `_config.yml`, or `nil` when the key is absent. Resolved once per build. |
| `reset_symbols` | Drops the cached map. Called from the `site, after_reset` hook this plugin registers, which is what scopes the cache to a build so `jekyll serve --watch` picks up an edit to a symbol file. |

## Development

```sh
bundle install
bundle exec rspec   # run the converter unit tests
```

### Which engine you are testing against

`bundle install` here does **not** resolve `carve-lang` from RubyGems. `Gemfile`
pins the engine to a carve-rb revision, so a development run measures one exact
engine build rather than whatever the registry serves that day, and
`script/verify_engine_pin.rb` refuses when the Gemfile, the resolved bundle and
the loaded library disagree. CI runs it before the suite:

```sh
bundle exec ruby script/verify_engine_pin.rb
# carve-lang 0.1.1 from carve-rb f15f30a2... (Gemfile pins f15f30a21e7a)
```

An installed copy of this gem resolves differently, through the range
`jekyll-carve.gemspec` declares - today `>= 0.1.1, < 0.2.0`. The two are
deliberately not the same engine, and both are checked:
`spec/engine_floor_spec.rb` asks whether the engine under `bundle exec rspec`
still does what the floor claims, and `script/consumer_engine_probe.rb` asks the
same of an actual `gem install`, daily in `Engine drift` and again before every
release.

There is no committed `Gemfile.lock`, and that is deliberate - the reasoning,
including why a lockfile would be a weaker pin here and what it would cost the
Ruby 3.1 job, is written at the top of `Gemfile`.
