# Development

## Setup and maintenance

```sh
bundle install
bundle exec rspec   # run the converter unit tests
```

### Which engine you are testing against

On `next2`, `Gemfile` pins `carve-lang` to a carve-rb `next2` commit (the
unreleased Carve 0.2 binding, compiled by Bundler), and
`script/verify_engine_pin.rb` refuses when the Gemfile, the resolved bundle and
the loaded library disagree. CI runs it before the suite:

```sh
bundle exec ruby script/verify_engine_pin.rb
# carve-lang 0.1.14 from https://github.com/markup-carve/carve-rb (Gemfile pins carve-rb 65fd034386b7b004386f631eb5951f9737072239)
```

An installed copy of this gem resolves differently, through the range
`jekyll-carve.gemspec` declares - today `>= 0.1.11, < 0.2.0`. The two can
differ, and both are checked:
`spec/engine_floor_spec.rb` asks whether the engine under `bundle exec rspec`
still does what the floor claims, and `script/consumer_engine_probe.rb` asks the
same of an actual `gem install`, daily in `Engine drift` and again before every
release.

There is no committed `Gemfile.lock`, and that is deliberate: a bundler 4
lockfile would need Ruby 3.2 or newer, and CI still runs a 3.1 job.
