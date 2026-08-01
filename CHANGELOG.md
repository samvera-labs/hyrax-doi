# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 1.0.0: a Valkyrie-native, flexible-metadata-aware rewrite. See the notes under
"Upgrading from 0.3.x" below — 1.0.0 is a deliberate breaking change and drops ActiveFedora.

### Changed

- **Minimum Hyrax is now 5.3.0.** The flexible metadata stack (`Hyrax::Flexibility`,
  `Hyrax::M3SchemaLoader`, `Hyrax::FlexibleSchema`, the `HYRAX_FLEXIBLE` config, and the
  `allinson` test app) first ships in 5.3.0 and is absent from every earlier 5.x release.
  Supporting both flex modes is a requirement, so there is no earlier version to support.
- Test harness now runs against Hyrax's own Valkyrie test apps: `koppie` (Postgres metadata,
  flex off), `allinson` (Postgres metadata, flex on), and `sirenia` (Fedora
  metadata/storage, flex off). CI runs all three.
- The Hyrax submodule tracks `main` rather than a release tag. The released `hyrax-v5.3.0`
  cannot boot — `Hyrax::Forms::ResourceForm` includes `CompoundFieldBehavior`, but the tag
  omits the file defining it. Pin to a release tag once a fixed one ships.
- `erb` is pinned to `~> 4.0`, matching Hyrax. Left unpinned, bundler resolves erb 6, whose
  `ERB.new` signature `sprockets 3.7.2` cannot call.
- `config.fixture_path=` replaced with `fixture_paths` (removed in RSpec Rails 7).
- Development and testing instructions moved from the README into a new
  [CONTRIBUTING.md](CONTRIBUTING.md).

### Added

- `Hyrax::DOI::PersistentIdentifier`, one row per identifier per resource. Replaces storing a
  DOI in a single overwritable attribute, so a resource can hold several identifiers at once
  (a DOI and a RAiD, say), each with its own state and sync history. Install the table with
  `rails g hyrax:doi:migrations` — the gem ships a generator rather than a migration.
- `Hyrax::DOI::RegistrationResult`, returned from `register!`. Carries state, errors, and the
  raw provider response, so a caller can tell a skip from a failure and record what happened.
- `Hyrax::DOI::RecordedIdentifier` with ORCID and ROR implementations, for identifiers that
  are recorded rather than minted. These have no `register!` and do not belong in the
  registrar interface.
- `Hyrax::DOI.config.default_providers`, mapping each scheme to the provider that mints it
  (`doi` → `datacite` by default) instead of hardcoding DataCite at each call site.
- `.ruby-version` pinning Ruby 3.3, matching the container and CI. Without it a version
  manager may select an older Ruby in which host-side rubocop cannot run.

### Deprecated

- Specs tagged `:active_fedora` are excluded from all three test apps. They are
  ActiveFedora-era specs awaiting rewrite, and each will be rewritten or removed as its part
  of the Valkyrie port lands.

### Removed

- The `bolognese` dependency, along with `Bolognese::Readers::HyraxWorkReader` and
  `Bolognese::Writers::HyraxWorkWriter`. DataCite REST v2 accepts JSON directly, so the XML
  crosswalk has no remaining purpose, and autofill moves to doi.org content negotiation.
  Drops 28 transitive dependencies.
- The exact `addressable` 2.8.1 pin, which existed to work around postrank-uri#49 — fixed in
  postrank-uri 1.1.
- The `dassie` (ActiveFedora) test harness: `docker-compose.yml`, `Gemfile.dassie`, and
  `Gemfile.dassie.lock`. The gem is Valkyrie-only as of 1.0.0.
- `chromedriver-helper` development dependency — unmaintained since 2019 and incompatible with
  current Chrome. The test apps' `chrome` service is used instead.
- The `simplecov` version pin (`0.17.1`), which existed to work around a long-since-resolved
  cc-test-reporter issue.

## [0.3.0]

Last ActiveFedora-based release. See the git history for changes prior to this changelog.

---

## Upgrading from 0.3.x

1.0.0 is a clean break with no compatibility shims. It targets current Hyrax and forward only;
0.3.x had not worked since Hyrax v3.

| 0.3.x | 1.0.0 |
|---|---|
| ActiveFedora `property :doi` | Valkyrie `attribute :doi`, derived from a PID record |
| `Hyrax::Actors::DOIActor` in the actor stack | A publisher listener on `object.metadata.updated` |
| `DataCiteRegistrar.prefix=` etc. (process-global `class_attribute`) | A per-call credential resolver; no global state |
| DataCite MDS API (XML) | DataCite REST API v2 (JSON:API) with explicit `event` transitions |
| `bolognese` for crosswalking | A direct DataCite serializer; autofill via doi.org content negotiation |
| Registration state inferred from `doi_status_when_public` | State stored on the PID record; the work keeps *intent* only |

For ActiveFedora applications, stay on the `0.3-stable` branch.
