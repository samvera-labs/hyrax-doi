# Hyrax::DOI
Code: [![CircleCI](https://circleci.com/gh/ubiquitypress/hyrax-doi.svg?style=svg)](https://circleci.com/gh/ubiquitypress/hyrax-doi)
[![Code Climate](https://codeclimate.com/github/ubiquitypress/hyrax-doi/badges/gpa.svg)](https://codeclimate.com/github/ubiquitypress/hyrax-doi)


Docs: [![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Jump in: [![Slack Status](http://slack.samvera.org/badge.svg)](http://slack.samvera.org/)

Hyrax-doi is a Hyrax plugin that provides tools for working with DOIs including model attributes, minting, and fetching descriptive metadata.

## Compatibilty
Hyrax-doi is compatible with Hyrax 2.8+ and tested with a [Hyrax 2.8.0 test application](https://github.com/ubiquitypress/hyrax_test_app) that mirrors the generated app used by Hyrax internally for testing.

## Usage
TODO

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'hyrax-doi'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install hyrax-doi
```

## Development

### Running Rake Tasks and Generators
When working on this engine rake tasks from Hyku can be run by prepending the `app` namespace (e.g. `rake app:db:migrate`). Generators provided by rails or other gems/engines can be run like normal from this engine's root (e.g. `rails g job UbiquityExporter`).

### Development Server

To run a development server locally outside of docker do the following with each line in its own shell from the root of the engine:
```
solr_wrapper -v --config .solr_wrapper.yml
fcrepo_wrapper -v --config .fcrepo_wrapper.yml
bundle exec sidekiq -r spec/internal_test_hyrax
bundle exec rails server -b 0.0.0.0
```

### Testing

Tests are run automatically on CircleCI with rubocop and codeclimate.  These tests must pass before pull requests can be merged.

To run the tests locally outside of docker do the following with each line in its own shell from the root of the engine:
```
solr_wrapper -v --config .solr_wrapper_test.yml
fcrepo_wrapper -v --config .fcrepo_wrapper_test.yml
bundle exec sidekiq -r spec/internal_test_hyrax
RAILS_ENV=test bundle exec rails server -b 0.0.0.0
bundle exec rspec
```
You shouldn't need to run anything from inside `spec/internal_test_hyrax` unless explicitly told to do so.
