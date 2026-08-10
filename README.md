# Hyrax::DOI
Code: [![Lint and Test](https://github.com/samvera-labs/hyrax-doi/actions/workflows/lint-test.yml/badge.svg)](https://github.com/samvera-labs/hyrax-doi/actions/workflows/lint-test.yml)
[![Code Climate](https://codeclimate.com/github/samvera-labs/hyrax-doi/badges/gpa.svg)](https://codeclimate.com/github/samvera-labs/hyrax-doi)


Docs: [![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Jump in: [![Slack Status](http://slack.samvera.org/badge.svg)](http://slack.samvera.org/)

Hyrax-doi mints DOIs for works in a Hyrax application, keeps the provider's copy of their
metadata current, and fills a deposit form from a DOI someone else has already minted.

## Features

### Minting is always something a person asks for

A DOI is never created as a side effect of saving a work. There are three ways to ask:

- **Choose a status on the deposit form.** *Do not mint* is the default; *Draft*,
  *Registered*, and *Findable* each mint when the work is saved.
- **Press "Create draft DOI" on the deposit form.** This reserves a DOI without submitting,
  so it can be written into the files being uploaded.
- **Press "Mint DOI" on the work's show page**, for a work deposited without one. Requires
  edit permission on that work.

**Updates are automatic, but only for works that already have a DOI.** Editing such a work
pushes its new metadata to the provider. Editing a work without one does nothing.

### Intent and state are separate

The status chosen on the form is the depositor's *intent*. What the provider currently
reports is recorded separately, and the two legitimately differ: a work marked *findable*
stays `registered` at DataCite while it is private, and becomes findable when the work
does — including when an embargo expires.

A draft DOI is reserved but does not resolve, so it is not shown on the show page.

### Autofill from an existing DOI

A depositor cataloguing something published elsewhere can paste its DOI and fill the form
from the metadata its publisher registered. This reads metadata; it mints nothing, and the
DOI is recorded as external so the gem never tries to update it.

Metadata is read from doi.org by content negotiation, so **any registration agency
resolves** — CrossRef, DataCite, JaLC, and the rest.

### More than one identifier per work

Identifiers are stored in their own table, one row per identifier, each with its own state
and sync history. A work can hold a DOI and another identifier at the same time without
either overwriting the other.

## Compatibility

Requires the **flexible metadata stack**, which first ships in **Hyrax 5.3.0**, and is
**Valkyrie-only**. The gem supports both `HYRAX_FLEXIBLE=false` and `HYRAX_FLEXIBLE=true`.

The declared floor is `hyrax >= 5.2` rather than 5.3: the 5.3.0 version bump was never
merged back to Hyrax's `main`, so an application tracking `main` reports 5.2.0 while running
the flexible stack. On a released Hyrax, use 5.3.0 or later.

ActiveFedora is not supported as of 1.0.0; use the `0.3-stable` branch for those
applications. An application migrating to Valkyrie is supported, provided its works are
Valkyrie resources.

Tested against Hyrax's own test applications in four configurations — koppie, allinson,
sirenia, and freyja — covering both flex modes, both Postgres and Fedora metadata
backends, and an application with Wings loaded. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Installation

Add the gem:

```ruby
gem 'hyrax-doi'
```

Then:

```bash
bundle install
rails g hyrax:doi:install --datacite
rails db:migrate
```

The generator adds an initializer, the identifier table's migration, the DOI attributes to
your `SolrDocument`, and the engine's routes. Then enable DOIs on each work type that
should have them:

```bash
rails g hyrax:doi:add_to_work_type Monograph
```

Set your DataCite credentials in the environment:

```bash
DATACITE_PREFIX=10.5072
DATACITE_USERNAME=...
DATACITE_PASSWORD=...
DATACITE_MODE=test        # or production; defaults to test
```

That is a working installation: the DOI tab appears on the deposit form for the work types
you enabled. Minting is governed by the `doi_minting` feature flag, which is on by default
and can be switched off per tenant from the Hyrax admin dashboard.

If your application does not already set `host` in `default_url_options`, set it — the URL
registered with each DOI is built from it.

## Configuration

Everything above works with no configuration. For per-tenant credentials, restricting which
work types may mint, deriving DataCite's required fields from your own metadata, or storing
the DOI in an attribute other than `doi`, see
[docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for setting up a development environment, running
specs against the four test apps, and linting.

For community guidelines — code of conduct, commit conventions, and the pull request
process — see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
