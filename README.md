# Hyrax::DOI
Code: [![CircleCI](https://circleci.com/gh/samvera-labs/hyrax-doi.svg?style=svg)](https://circleci.com/gh/samvera-labs/hyrax-doi)
[![Code Climate](https://codeclimate.com/github/samvera-labs/hyrax-doi/badges/gpa.svg)](https://codeclimate.com/github/samvera-labs/hyrax-doi)


Docs: [![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Jump in: [![Slack Status](http://slack.samvera.org/badge.svg)](http://slack.samvera.org/)

Hyrax-doi is a Hyrax plugin that provides tools for working with DOIs including model attributes, minting, and fetching descriptive metadata.

## Features
### DOI Creation and Updating
DOIs are created and updated when a work of a DOI-enabled work type is saved.  This happens in a background job using the [external identifier interface](https://github.com/samvera/hyrax/pull/4458) provided by Hyrax.

>Note: At this point only functionality for registering DOIs wtih DataCite is implemented but other registrars should be also be possible.

#### Draft DOI Creation (DataCite)
The deposit form has a button for creating a draft DOI without requiring submitting the form.  This is useful if you need to know the DOI and embed it in the uploaded file(s).

#### DOI Status Support (DataCite)
The uploader is allowed to choose the DOI status (draft, registered, findable) they want for the work when it becomes public.  If findable is chosen the DOI will remain as registered until the work become public.

#### Form Validation (DataCite)
Hyrax-doi will provide defaults or placeholders for fields which Hyrax doesn't require but which are mandatory for DataCite.  In this case the uploader will be notified of the missing fields and given the opportunity of filling them in before submittign or of continuing with the defaults. 

### Form autofilling
When submitting a work with an existing DOI (like a scholarly article), the uploader can fill in the DOI and click a button to autofill the deposit form with metadata from the DOI.  This is not limited to DataCite and works with DOIs from a variety of registrars (DataCite, CrossRef, JaLC, ISTIC, , etc.)

### Metadata Crosswalking
DOI submission and form autofilling happens by crosswalking the work's metadata with DataCite's schema through the [bolognese gem](https://github.com/datacite/bolognese) which enables crosswalking with a number of metadata formats besides those required by DOI registars including RIS, BibTeX, Crosscite, and Schema.org.

## Compatibilty
Hyrax-doi is compatible with Hyrax 2.9+ and tested with a [Hyrax 2.9.0 test application](https://github.com/ubiquitypress/hyrax_test_app) that mirrors the generated app used by Hyrax internally for testing.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'hyrax-doi'
```

And then execute:
```bash
$ bundle
```

Then run the install generator
```
rails g hyrax:doi:install
```
Use the `--datacite` flag if working with DataCite DOIs:
```
rails g hyrax:doi:install --datacite
```

## Usage

### Enable DOI functionality for a work type
Run the generator to add DOI support to a given work type:
```
rails g hyrax:doi:add_to_work_type MyWorkType
```
Add the `--datacite` flag if creating DataCite DOIs:
```
rails g hyrax:doi:add_to_work_type MyWorkType --datacite
```

### Configuration
After the install generator is run, Hyrax-doi can be configured in the `config/initializers/hyrax-doi.rb` initializer.

If your application does not already set `host` in `default_url_options`, you will need to configure it for creating full urls to work show pages to be registered with DOIs.

DataCite credentials can either be set in environment variables (DATACITE_PREFIX, DATACITE_USERNAME, and DATACITE_PASSWORD) or set in the initializer.  Hyrax-doi defaults to using DataCite's test environment but can be switched to the production environment by setting the mode:
```
Hyrax::DOI::DataCiteRegistrar.mode = :production
```

### Using with Hyku
Hyrax-doi is currently implemented for a single-tenant Hyrax application with configuration shared application wide.  Work to support per tenant configuration is under way and will live in its own engine or be contributed directly to Hyku.

## Development

### Setting up Development Environment
After checking out the code, initialize the internal hyrax test application:
```
git submodule init
git submodule update
```

### Running Rake Tasks and Generators
When working on this engine rake tasks from Hyrax can be run by prepending the `app` namespace (e.g. `rake app:db:migrate`). Generators provided by rails or other gems/engines can be run like normal from this engine's root (e.g. `rails g job CheckDOIResolution`).

### Development Server

To run a development server locally outside of docker do the following with each line in its own shell from the root of the engine:
```
solr_wrapper -v --config .solr_wrapper.yml
fcrepo_wrapper -v --config .fcrepo_wrapper.yml
bundle exec rails server -b 0.0.0.0
```

### Testing

Tests are run automatically on CircleCI with rubocop and codeclimate.  These tests must pass before pull requests can be merged.

To run the tests locally outside of docker do the following with each line in its own shell from the root of the engine:
```
solr_wrapper -v --config .solr_wrapper_test.yml
fcrepo_wrapper -v --config .fcrepo_wrapper_test.yml
bundle exec rspec
```
You shouldn't need to run anything from inside `spec/internal_test_hyrax` unless explicitly told to do so.
