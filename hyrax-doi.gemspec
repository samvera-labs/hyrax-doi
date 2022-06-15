# frozen_string_literal: true
$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "hyrax/doi/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "hyrax-doi"
  spec.version     = Hyrax::DOI::VERSION
  spec.authors     = ["Chris Colvard"]
  spec.email       = ["chris.colvard@gmail.com"]
  spec.homepage    = ""
  spec.summary     = "Hyrax plugin for working with DOIs."
  spec.description = "Tools for working with DOIs in Hyrax including model attributes, minting, and fetching descriptive metadata."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 5.2.4", ">= 5.2.4.3"

  spec.add_dependency "hyrax", ">= 2.9", "< 4.0"
  spec.add_dependency "flipflop", "~> 2.3"
  spec.add_dependency "bolognese", "~> 1.8", ">= 1.8.6"

  spec.add_development_dependency 'flipflop'
  spec.add_development_dependency 'ammeter'
  spec.add_development_dependency 'capybara'
  spec.add_development_dependency 'chromedriver-helper', '~> 2.1'
  spec.add_development_dependency "bixby"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "pg"
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'webdrivers', '~> 4.0'
  spec.add_development_dependency 'webmock'
  # Workaround for cc-test-reporter with SimpleCov 0.18.
  # Stop upgrading SimpleCov until the following issue will be resolved.
  # https://github.com/codeclimate/test-reporter/issues/418
  spec.add_development_dependency('simplecov', '0.17.1', '< 0.18')
end
