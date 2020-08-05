# frozen_string_literal: true
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in hyrax-doi.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

gem 'hydra-head', path: '/home/cjcolvar/Code/samvera/hydra-head'
gem 'hydra-access-controls', path: '/home/cjcolvar/Code/samvera/hydra-head/hydra-access-controls'
#gem 'browse-everything', git: 'https://github.com/samvera/browse-everything.git'
gem 'bolognese', path: '/home/cjcolvar/Code/tmp/bolognese'

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use a debugger
# gem 'byebug', group: [:development, :test]

eval_gemfile File.expand_path('spec/internal_test_hyrax/Gemfile', File.dirname(__FILE__))
