# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The Carve parser gem (`carve-lang`) is a native extension over the carve-rs
# engine. It compiles its Rust extension at install time, so a Rust toolchain is
# required either way.
#
# The git source is deliberate, not an oversight. It used to be justified by
# RubyGems being behind - 0.1.0 was all that was published, and 0.1.1 was an
# unpublished draft (carve#499). That stopped being true on 2026-08-18, and the
# gap has since reversed: carve-lang 0.1.7 is current on RubyGems, which is what
# a consumer of this gem resolves through the gemspec range. The source stays
# because a REVISION is a stronger statement than a version for a run whose job
# is to be reproducible, not because RubyGems has nothing to offer.
#
# WHICH MAKES THE REF SOMETHING TO KEEP MOVING. The drift job below reports a
# lag as a `::warning::` and stays green, by design - upstream moving is not
# this repo's failure - but nothing here opens a bump pull request the way
# markup-carve/wp-carve and markup-carve/intellij-carve do. So the pin sat at
# carve-rb v0.1.4 while v0.1.5, v0.1.6 and v0.1.7 published, and four of seven
# boundary shapes rendered differently between the pinned engine and the one a
# consumer installs. spec/rendering_rulings_spec.rb is what notices that now:
# every example in it failed at v0.1.4.
#
# The consequence is that no routine run here resolves the engine a consumer
# gets. That is what the `consumer` job in
# `.github/workflows/engine-drift.yml` is for.
#
# PINNED to a revision. Without a ref this floated on whatever sat on the
# default branch at install time, so CI and a contributor could resolve
# different engines with nothing to read that said so.
# The sibling-checkout escape hatch is OPT-IN, and that is not a style
# preference. It used to trigger on `File.directory?`, so merely HAVING a
# carve-rb checkout beside this one silently replaced the pinned engine with
# whatever that working tree happened to be parked on - no output, nothing in
# the diff, and `Gemfile.lock` recording a PATH source that a contributor
# without the sibling never sees.
#
# Measured here rather than supposed. With a sibling parked on a commit from
# the day before, `bundle exec rspec` was 12 of 12 green while the engine under
# it still rendered:
#
#   ![x](safe.png){srcset="safe.png 1x, javascript:alert(1) 2x"}
#   -> <img src="safe.png" alt="x" srcset="safe.png 1x, javascript:alert(1) 2x">
#
# Bumping the `ref:` below changed nothing, because the ref branch was never
# taken. An env var has to be set on purpose, so the surprising resolution is
# the one you asked for.
# WHY THERE IS NO COMMITTED Gemfile.lock, and what the `ref:` below is instead.
#
# The usual answer to "CI resolved whatever the registry served" is a committed
# lockfile. It is the wrong instrument twice over here:
#
#   * For the ENGINE it would be WEAKER than what is already there. A lockfile
#     entry names a VERSION (`carve-lang (0.1.2)`); the `ref:` below names a
#     COMMIT. Two carve-rb builds can carry the same package version.
#   * For everything else it would cost the oldest Ruby this gem supports.
#     Measured 2026-08-21: `bundle install` here writes `BUNDLED WITH 4.0.18`,
#     and bundler 4.0.x requires Ruby >= 3.2.0, while `ci.yml` runs a 3.1 leg
#     and the gemspec says `>= 3.0.0`. `ruby/setup-ruby` installs the bundler
#     the lockfile names, so committing this one turns the 3.1 job red on a
#     file nobody edited.
#
# A published gem also has no business shipping a lockfile: a consumer resolves
# through the gemspec range, never through this file.
#
# So the engine is pinned by revision and READ BACK - `script/verify_engine_pin.rb`
# runs in CI and refuses unless the Gemfile, the resolved bundle and the loaded
# library name the same engine. The rest of the bundle still floats on purpose,
# and the `suite` job in `.github/workflows/engine-drift.yml` is what notices a
# transitive gem changing under it.
#
carve_rb = ENV["CARVE_RB_PATH"]
if carve_rb && !carve_rb.empty?
  raise "CARVE_RB_PATH=#{carve_rb} is not a directory" unless File.directory?(carve_rb)

  gem "carve-lang", path: File.expand_path(carve_rb)
else
  gem "carve-lang", git: "https://github.com/markup-carve/carve-rb.git", ref: "048765a975adeae1d73c22fe9069ccea2fbfd9bd"  # carve-rb v0.1.7, identical to its main
end
