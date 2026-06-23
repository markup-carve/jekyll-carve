# jekyll-carve

A [Jekyll](https://jekyllrb.com) converter plugin for the
[Carve](https://github.com/markup-carve/carve) markup language. It renders
`.crv` / `.carve` pages to HTML by delegating to the native
[`carve`](https://github.com/markup-carve/carve-rb) gem (`Carve.to_html`). No
parser is reimplemented here; this is a thin `Jekyll::Converter` adapter over
the engine, mirroring how [`jekyll-djot`](https://github.com/jgm/djot) integrates
Djot.

## Install

Add both gems to your site's `Gemfile`:

```ruby
# Gemfile
gem "jekyll-carve"
gem "carve" # the native Carve engine (a runtime dependency, listed for clarity)
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
> The `carve` gem ships a Rust native extension and is compiled at install
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

## Usage

Create a page with a `.crv` (or `.carve`) extension. It MUST begin with Jekyll
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
| `matches(ext)` | `true` for `.crv` / `.carve` (with or without the leading dot, case-insensitive), `false` otherwise. |
| `output_ext(ext)` | `".html"` (includes the dot so Jekyll emits `page.html`). |
| `convert(content)` | `Carve.to_html(content, extensions: configured)` - the rendered HTML. |
| `carve_extensions` | The extension list read from `carve.extensions` in `_config.yml` (empty by default). |

## Development

```sh
bundle install
rspec            # run the converter unit tests
```

## License

MIT, markup-carve.
