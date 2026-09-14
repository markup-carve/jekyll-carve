# Development

## Setup and maintenance

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
# carve-lang 0.1.2 from carve-rb b7f3a91a... (Gemfile pins b7f3a91a4192)
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
