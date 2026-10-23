# Development

## Setup and maintenance

```sh
bundle install
bundle exec rspec   # run the converter unit tests
```

### Which engine you are testing against

`Gemfile` pins `carve-lang` to one exact released version from RubyGems, so a
development run measures a version a consumer can install rather than whatever
the gemspec range resolves that day, and
`script/verify_engine_pin.rb` refuses when the Gemfile, the resolved bundle and
the loaded library disagree. CI runs it before the suite:

```sh
bundle exec ruby script/verify_engine_pin.rb
# carve-lang 0.1.11 from https://rubygems.org/ (Gemfile pins 0.1.11)
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
