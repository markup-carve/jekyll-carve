# jekyll-carve guide

## Background

A [Jekyll](https://jekyllrb.com) converter plugin for the
[Carve](https://github.com/markup-carve/carve) markup language. It renders
`.crv` pages to HTML by delegating to the native
[`carve-lang`](https://github.com/markup-carve/carve-rb) gem (`Carve.to_html`). No
parser is reimplemented here; this is a thin `Jekyll::Converter` adapter over
the engine.

## Installation notes

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
> On `next2`, `carve-lang` is the unreleased Carve 0.2 binding, pinned in
> `Gemfile` to a carve-rb `next2` commit. Bundler compiles its Rust extension,
> which needs Rust 1.88 or newer (`cargo`), libclang and Ruby development headers.

## Configuration

Carve engine options are read from `_config.yml` under the `carve` key:

```yaml
carve:
  extensions:
    - carve.details
    - carve.mathBlock
    - carve.fencedRender.mermaid
```

`carve.extensions` lists Carve 0.2 standard extensions, each rendered with its
standard renderer. When the key is absent, no extensions are enabled. An unknown
name is an `ArgumentError` at build time.

A 0.1 name is read as its 0.2 counterpart, in either spelling (`math_block` or
`math-block`): `details`, `spoiler`, `tabs`, `code-group`, `code-callouts`,
`list-table`, `math-block`, `fenced-render` (`carve.fencedRender.mermaid`),
`fenced-render-<word>` (graphviz also claims `dot`, plantuml also `puml`), `semantic-span`, `smart-quotes`, `color-swatch`,
`wikilinks` (`carve.wiki`), `citations` (`carve.references`), `glossary`,
`index`, `img-fence`, `tab-normalize`, and the navigation extensions
`heading-permalinks`, `heading-numbers`, `heading-level-shift`,
`heading-reference`, `table-of-contents` and `toc` (`carve.toc`),
`external-links`, `autolink` and `link-policy`. `carve.tocPlacement` has no 0.1
name; give it as written.

The 0.2 Ruby binding enables an extension by name only, so `carve.extensions`
takes names, not options. In an included file, an extension claims its
construct only when the including page uses it too
([carve-rs#4481](https://github.com/markup-carve/carve-rs/issues/4481)).

### `carve.raw_html`

Carve 0.2 escapes `=html` blocks and spans by default. `raw_html: true` emits
them verbatim; set it only when the site's own authors write every page.

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

### `carve.includes` - pulling one file into another

A Carve page can pull another file in with `{{ path }}`. It stays literal until
the site asks:

```yaml
carve:
  includes: true
```

Paths resolve relative to the file that wrote them, and nothing resolves outside
the containment root. The root is Jekyll's source directory unless
`carve.include_root` names another one, and an include that would leave it is
not expanded.

```yaml
carve:
  includes: true
  include_root: /srv/shared/fragments
```

`carve.include_root` must be an **absolute** path. A relative one is refused
rather than resolved, because resolving it lands on whatever directory the build
ran from, which is not a root anyone chose. The page being rendered has to sit
inside the root too.

A target that cannot be read is reported against the page that asked for it, and
the directive is left as written. The code names the cause: `include-not-found`,
`include-outside-root`, `include-cycle` and the other codes of Carve 0.2
(C2-N-061). A directive inside a sentence is text in 0.2 and is never expanded
(C2-N-002).

Under `jekyll serve`, a page is rebuilt when a target it read changes, because
every resolved target is registered with Jekyll's regeneration path.

A conversion with no page behind it - the converter called directly on a String -
leaves the directive literal, since there is no file for a relative path to
resolve against.

> [!NOTE]
> Fragments under the source directory are pages in their own right, so Jekyll
> will publish them. Exclude them in `_config.yml`, or keep them outside the
> source and point `include_root` at the tree above both.

### `carve.lint` - reporting what renders but is lost

Carve's linter reports constructs that parse and render, but not the way the
author meant: a block attribute that attaches to nothing, a link to an id no
heading has, an unclosed code fence. Turn it on to see them as build warnings:

```yaml
carve:
  lint: true
```

```
Carve lint: guide/intro.crv:7:1: unattached-block-attribute: This block attribute reaches no block: ...
```

Each warning names the page, the line and column in the file, and the rule id.
The line counts the front matter, so it matches your editor; a Liquid tag that
expands to several lines shifts the lines below it, since the linter reads the
page after Liquid. Pages still render.

To fail the build instead, use `strict`:

```yaml
carve:
  lint: strict
```

Every page is linted and reported first, then `jekyll build` stops with an
error before writing the site.

The 0.2 linter reads no extensions (C2-W-109), so `carve.extensions` does not
change what it reports. With `carve.includes` on it also lints each included Carve file, and a finding there
names that file: `index.crv (parts/intro.crv:3:1): ...`. Include warnings such
as `include-not-found` are logged once, by the include pass, but count toward
`strict`. Without `carve.includes`, each directive is a finding,
`include-no-resolver`.

A newer engine can report findings an older one did not, so a site that passes
`strict` today can fail after an engine upgrade. The engine reports a `---`
thematic break as `thematic-break-spelling` (write `***`) and the glued
alignment markers `|=<`, `|=~`, `|=>` as `deprecated-cell-alignment` (write
`|={<}`, `|={~}`, `|={>}`). In Carve 0.2 a glued marker is cell text (U-056), and
`caption-looking-paragraph` is on by default.

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

## Highlighting Carve code blocks

This plugin renders `.crv` pages. To highlight a ` ```carve ` block inside a
Markdown page, add [rouge-carve](https://github.com/markup-carve/rouge-carve),
which registers a Carve lexer with Rouge, Jekyll's default highlighter:

```ruby
# Gemfile
group :jekyll_plugins do
  gem "rouge-carve"
end
```

Jekyll requires every gem in the `jekyll_plugins` group on its own. Without
that group, list it in `_config.yml` instead:

```yaml
plugins:
  - jekyll-carve
  - rouge-carve
```

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
