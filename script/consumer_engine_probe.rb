#!/usr/bin/env ruby
# frozen_string_literal: true

# WHAT DOES AN INSTALL OF THIS GEM ACTUALLY RENDER?
#
# `Gemfile` pins the engine by carve-rb revision, so no ordinary run in this
# repository ever resolves `carve-lang` from RubyGems. A consumer only ever
# does. Those are different engines, and this repository has already been bitten
# by the difference - which is why the question is asked of an INSTALLED gem in
# an isolated GEM_HOME rather than of the checkout.
#
# Run it with GEM_HOME pointing at a prefix where the built `jekyll-carve` gem
# has been installed, so RubyGems resolved `carve-lang` through the range the
# gemspec declares. It is used by two jobs that ask the question for different
# reasons:
#
#   * `.github/workflows/release.yml` - before publishing, because a floor is a
#     claim about what a consumer resolves and this is the only way to check it
#     rather than restate it.
#   * `.github/workflows/engine-drift.yml` - daily, because pinning every
#     routine run makes each one reproducible and the repository blind. No
#     pinned run ever meets a carve-lang published after the pin. This is the
#     run that does, a day after a release rather than in whoever's pull request
#     happens to be next.

def refuse(message)
  warn "::error::#{message}"
  exit 1
end

# THE CONSUMER'S OWN ORDER, and it is load-bearing. Activating jekyll-carve
# first means RubyGems picks carve-lang through the range the gemspec declares,
# the way `require "jekyll-carve"` does in a site's Gemfile. Requiring "carve"
# on its own would activate the NEWEST carve-lang the environment can see,
# which is a different question and would report an engine no consumer of this
# gem resolves.
begin
  gem "jekyll-carve"
  require "jekyll-carve"
rescue Gem::LoadError, LoadError => e
  refuse "jekyll-carve does not load in GEM_HOME=#{ENV.fetch('GEM_HOME', '(unset)')}: #{e.message}"
end

# --- Did the declared range govern this install? -----------------------------

begin
  installed = Gem::Specification.find_by_name("jekyll-carve")
rescue Gem::MissingSpecError
  refuse "jekyll-carve is not installed in GEM_HOME=#{ENV.fetch('GEM_HOME', '(unset)')}, " \
         "so nothing here resolved through the gemspec and this probe would be measuring " \
         "some other engine"
end

# A BACKSTOP, not the mechanism. The activation above is what makes the range
# govern; this reports the case where it did not - a stray carve-lang activated
# earlier, or a probe run outside the isolated GEM_HOME it was meant for.

dependency = installed.dependencies.find { |d| d.name == "carve-lang" }
refuse "the installed jekyll-carve #{installed.version} declares no carve-lang dependency" if dependency.nil?

resolved = Gem::Version.new(Carve::VERSION)
unless dependency.requirement.satisfied_by?(resolved)
  refuse "jekyll-carve #{installed.version} declares carve-lang #{dependency.requirement}, " \
         "but #{resolved} is what loaded - the probe is not reading the install it thinks it is"
end

puts "jekyll-carve #{installed.version} declares carve-lang #{dependency.requirement}; " \
     "this install resolved #{resolved}"

# --- Does that engine still sanitize what the floor was set for? -------------

source = %q(![a](x.png){srcset="safe.png 1x, javascript:alert(1) 2x"})
html = Carve.to_html(source).strip
puts "carve-lang #{resolved} -> #{html}"

# Checked FIRST, and separately: an engine that raised, rendered nothing or
# dropped the element would pass the sanitization check below by producing no
# output, and this probe would report a security property it never measured.
unless html.include?("<img") && html.include?(%(src="x.png"))
  refuse "the resolved engine rendered no image, so the check below would pass vacuously: #{html}"
end

if html.include?("javascript:")
  refuse "the engine a consumer resolves leaks a javascript: URL from a non-first " \
         "entry of a list-valued attribute"
end
