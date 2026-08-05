# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 1.0.0: a Valkyrie-native, flexible-metadata-aware rewrite. See the notes under
"Upgrading from 0.3.x" below — 1.0.0 is a deliberate breaking change and drops ActiveFedora.

### Changed

- **The DataCite client speaks REST v2 only.** State is set by an explicit `event`
  (`register`, `publish`, `hide`) on one idempotent `PUT /dois/:id`, rather than emerging
  from the side effects of a metadata call, a url call, and a corrective delete. A work
  whose intent is *findable* but which is not yet public is hidden rather than published,
  so it resolves for anyone holding the DOI without being publicly indexed.
- `DataCiteRegistrar#register!` returns a `RegistrationResult` carrying the state DataCite
  reported, whether anything was sent, and any field-level errors. Missing required
  metadata is reported by name before the request is made, rather than surfacing as a
  DataCite rejection.
- **`DataCiteRegistrar.prefix=`, `.username=`, `.password=`, and `.mode=` are gone.**
  Credentials are now held per registrar instance and resolved per call. Those were
  `class_attribute`s, which are process-wide: two Sidekiq threads serving different tenants
  could overwrite each other's credentials mid-flight. Configure a credential store instead.
- `:doi_minting` is now actually consulted before registering. The check was previously
  stubbed to always return true.
- Work types now carry `doi` as a Valkyrie attribute instead of an ActiveFedora
  `property`, and `doi_status_when_public` records the depositor's **intent** only. What
  the provider currently reports lives on the `PersistentIdentifier` record, reachable as
  `doi_state`. The two legitimately differ: a work intended to be findable stays
  registered while it is private.
- **Minimum Hyrax is now 5.3.0.** The flexible metadata stack (`Hyrax::Flexibility`,
  `Hyrax::M3SchemaLoader`, `Hyrax::FlexibleSchema`, the `HYRAX_FLEXIBLE` config, and the
  `allinson` test app) first ships in 5.3.0 and is absent from every earlier 5.x release.
  Supporting both flex modes is a requirement, so there is no earlier version to support.
- Test harness now runs against Hyrax's own test apps: `koppie` (Postgres metadata, flex
  off), `allinson` (Postgres metadata, flex on), `sirenia` (Fedora metadata/storage), and
  `freyja` (dassie with `VALKYRIE_TRANSITION=true`, the only target with Wings loaded). CI
  runs all four.
- The Hyrax submodule tracks `main` rather than a release tag. The released `hyrax-v5.3.0`
  cannot boot — `Hyrax::Forms::ResourceForm` includes `CompoundFieldBehavior`, but the tag
  omits the file defining it. Pin to a release tag once a fixed one ships.
- `erb` is pinned to `~> 4.0`, matching Hyrax. Left unpinned, bundler resolves erb 6, whose
  `ERB.new` signature `sprockets 3.7.2` cannot call.
- `config.fixture_path=` replaced with `fixture_paths` (removed in RSpec Rails 7).
- Development and testing instructions moved from the README into a new
  [CONTRIBUTING.md](CONTRIBUTING.md).

### Added

- `Hyrax::DOI::DataCiteSerializer`, building a DataCite REST v2 payload from a work. Which
  work field feeds which DataCite field is read from `datacite_mapping` on m3 profile
  properties, so it can be changed without a deploy:

  ```yaml
  contributor:
    datacite_mapping: creators
  ```

  Values that must be derived rather than read come from a configured extractor instead —
  a repository with no `creator` field can build creators from its typed-role
  contributors:

  ```ruby
  Hyrax::DOI.configure do |config|
    config.creator_extractor = ->(work) { ... }
  end
  ```

  `#missing_required` reports which fields a registered or findable DOI still needs, so a
  caller can say so before DataCite rejects the submission.
- `Hyrax::DOI::CredentialStore`, the seam credentials are read through. Defaults to
  `EnvCredentialStore` (`DATACITE_PREFIX`, `DATACITE_USERNAME`, `DATACITE_PASSWORD`,
  `DATACITE_MODE`), which is enough for a single-tenant application:

  ```ruby
  Hyrax::DOI.configure do |config|
    config.credential_store = MyTenantAwareStore.new
  end
  ```

  The gem ships no persistence model — a host that already stores provider credentials
  should not be handed a second place to keep them.
- `CredentialStore.field_schema_for('datacite')`, describing the fields a provider needs
  (including which are secret and which offer fixed choices), so an admin form can render
  itself instead of hardcoding field names.
- `DataCiteRegistrar#ping`, confirming both that DataCite is reachable and that the
  credentials work, without minting anything or consuming quota. An outage and a rejected
  password report differently, so the message is actionable.
- `holds_doi_in`, so a work type can hold its DOI in an attribute other than `doi`:

  ```ruby
  class Monograph < Hyrax::Work
    include Hyrax::DOI::DOIBehavior
    holds_doi_in :identifier
  end
  ```

  Read it back with `doi_value` regardless of the name. Where the host already declares
  the attribute — from a metadata profile, a YAML schema, or its own DOI support — that
  declaration wins and the gem does not redeclare it.
- `Hyrax::DOI::Indexers::DOIIndexer`, emitting `doi_ssim`, `doi_tesim`,
  `doi_status_when_public_ssi`, and `doi_state_ssi`. A no-op where a schema loader
  already supplies those keys.
- `config/metadata/doi.yaml`, so a non-flex application can `include Hyrax::Schema(:doi)`.
- `rails hyrax:doi:install_flexible_profile`, adding the `doi` properties to an m3 profile.
  It creates a **new** profile version rather than editing the current one, since saved
  works pin `schema_version` to a row id. Pass `CLASSES=Monograph,Image` to limit which
  work types receive them.
- A profile validator that warns when an m3 profile's `doi` property is missing, has no
  `view:` block (which would keep it off the show page), or is available on no class the
  profile declares. It only ever warns: the attribute may be declared on the work class
  alone, which no profile can see.
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

- The legacy MDS API. `put_metadata`, `delete_metadata`, `get_metadata`, `get_url`,
  `register_url`, and `delete_draft_doi` are replaced by `put_doi`, `get_doi`, and
  `delete_doi` against `api.datacite.org`.
- The `bolognese` dependency, along with `Bolognese::Readers::HyraxWorkReader` and
  `Bolognese::Writers::HyraxWorkWriter`. DataCite REST v2 accepts JSON directly, so the XML
  crosswalk has no remaining purpose, and autofill moves to doi.org content negotiation.
  Drops 28 transitive dependencies.
- The exact `addressable` 2.8.1 pin, which existed to work around postrank-uri#49 — fixed in
  postrank-uri 1.1.
- The ActiveFedora-only `docker-compose.yml` and its committed `Gemfile.dassie.lock`. The
  dassie app is still used, but only via the `freyja` target, which runs it with
  `VALKYRIE_TRANSITION=true` so writes come back as Valkyrie.
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
