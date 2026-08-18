# Changelog

Notable changes to `jekyll-carve`.

Rendering is done by the Carve engine (`carve-lang`, the magnus binding over
carve-rs), so an engine change can alter output with no plugin diff. Engine
moves therefore get an entry of their own.

## Unreleased

Prepared as 0.1.0. Not released: see the note below.

### Added

- Jekyll converter for the Carve markup language. `.crv` pages render to HTML
  through the native `carve-lang` gem, with no parser reimplemented here.

### Fixed

- The development engine could be replaced silently. `Gemfile` selected a
  sibling `../carve-rb` checkout whenever that directory merely existed, so
  having one beside this repository swapped the pinned engine for whatever that
  working tree was parked on - with nothing in the diff and nothing in the
  output to say so. Measured: a sibling one day stale left `bundle exec rspec`
  12 of 12 green while the engine under it still emitted
  `srcset="safe.png 1x, javascript:alert(1) 2x"` unsanitized, and bumping the
  `ref:` changed nothing because that branch was never taken. The escape hatch
  is opt-in through `CARVE_RB_PATH` now.
- The pinned carve-rb revision moves 32 commits forward, onto the release
  freeze. The engine it builds no longer carries the list-valued URL defect.

### Not released, and why

`jekyll-carve.gemspec` depends on `carve-lang >= 0.1.0`, and 0.1.0 is the only
carve-lang on RubyGems. That release predates the Carve 0.1.3 security release,
and it is vulnerable - verified by installing it and rendering the case above,
which comes back unsanitized.

So publishing this gem today would ship a plugin whose every consumer resolves
a vulnerable engine, while this repository's own suite is green against a
patched one. The floor cannot simply be raised either: no patched `carve-lang`
exists on RubyGems to raise it to. This release waits on carve-rb publishing.
