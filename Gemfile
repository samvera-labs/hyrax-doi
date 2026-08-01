# frozen_string_literal: true
source 'https://rubygems.org'

# Please see hyrax.gemspec for dependency information.
# Install gems from test app
if ENV['RAILS_ROOT']
  test_app_gemfile_path = File.expand_path('Gemfile', ENV['RAILS_ROOT'])
  eval_gemfile test_app_gemfile_path
else
  gemspec
end

# Match Hyrax's own constraint. Without pinning, bundler resolves erb 6, whose
# ERB.new signature sprockets 3.7.2 cannot call -- the asset pipeline then raises
# "wrong number of arguments (given 3, expected 1)" on any .erb asset.
gem 'erb', '~> 4.0'

group :development, :test do
  gem 'ammeter'
  gem 'benchmark-ips'
  gem 'bixby'
  gem 'capybara'
  gem 'easy_translate'
  gem 'factory_bot_rails'
  gem 'i18n-tasks'
  gem 'pry' unless ENV['CI']
  gem 'pry-byebug' unless ENV['CI']
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'ruby-prof', require: false
  gem 'semaphore_test_boosters'
  gem 'shoulda-matchers', '~> 6.5'
  gem 'simplecov', require: false
  gem 'timecop'
  gem 'webmock'
end
