# Development

## Setup and maintenance

```sh
bundle install
bundle exec rspec   # run the converter unit tests
```

### Which engine you are testing against

`Gemfile` pins `carve-lang` to a carve-rb commit (the
unreleased Carve 0.2 binding, compiled by Bundler), and
`script/verify_engine_pin.rb` refuses when the Gemfile, the resolved bundle and
the loaded library disagree. CI runs it before the suite:

```sh
bundle exec ruby script/verify_engine_pin.rb
# carve-lang 0.2.0 from https://github.com/markup-carve/carve-rb (Gemfile pins carve-rb ca957d13fa9a2c83329298c4350be92ddff76cbb)
```

An installed copy of this gem resolves differently, through the range
`jekyll-carve.gemspec` declares - today `>= 0.2.0, < 0.3.0`. The two can
differ, and both are checked:
`spec/engine_floor_spec.rb` asks whether the engine under `bundle exec rspec`
still does what the floor claims, and `script/consumer_engine_probe.rb` asks the
same of an actual `gem install`, daily in `Engine drift` and again before every
release.

There is no committed `Gemfile.lock`, and that is deliberate: a bundler 4
lockfile would need Ruby 3.2 or newer, and CI still runs a 3.1 job.
