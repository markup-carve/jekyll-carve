# Changelog

Notable changes to `jekyll-carve`.

Rendering is done by the Carve engine (`carve-lang`, the magnus binding over
carve-rs), so an engine change can alter output with no plugin diff. Engine
moves therefore get an entry of their own.

## [0.1.0] - 2026-08-19

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

### Security

- The `carve-lang` floor moves to `>= 0.1.1`. At `>= 0.1.0` a consumer could
  resolve carve-lang 0.1.0, which predates the Carve 0.1.3 security release and
  renders a list-valued URL attribute unsanitized - so this plugin's own suite
  could be green while every install of it carried a vulnerable engine. 0.1.1 is
  the rebuild onto carve-rs 0.1.3, and the development pin moves to that tag's
  commit so the engine under `bundle exec rspec` is the one the gemspec now
  requires.
