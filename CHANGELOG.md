# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 1.0.0: a Valkyrie-native, flexible-metadata-aware rewrite. See the notes under
"Upgrading from 0.3.x" below — 1.0.0 is a deliberate breaking change and drops ActiveFedora.

### Changed

- **The tab's buttons reach the routes the application serves.** The views built their URLs
  with `Engine.routes.url_helpers`, which resolves against the engine's own route set and so
  ignores where the host mounted it — the autofill, reserve-a-DOI, and mint buttons all
  posted to paths nothing served. They now use the mounted `hyrax_doi` proxy, so any mount
  point works. The suite mounts the engine for every spec type rather than only feature
  specs, which is why no view spec could catch this.
- **The install generator reports a mount it could not add.** `inject_into_file` only warns
  on a missing anchor, so an application whose `config/routes.rb` did not match got a working
  DOI tab whose buttons 404. It now falls back to the routes block, and prints the line to
  add when neither anchor is found.
- **A DOI entered on the deposit form is saved, and a minted one is recorded.** The form
  concerns delegated readers to the work but declared no writable property, so
  `ResourceForm` discarded `doi` and `doi_status_when_public` on submit; nothing created a
  `PersistentIdentifier` row, so `doi_state` was always nil, the sync job — which returns
  early unless a minted record exists — never ran, and a reserved draft DOI existed only at
  DataCite. Minting now writes a record through `Hyrax::DOI::IdentifierRecorder`, which also
  keeps the work's DOI attribute in step for indexing and display.
- **The DOI tab's three modes no longer submit each other's values.** A hidden panel still
  posts its inputs, so a depositor who typed a DOI and then chose to mint a new one, or to
  mint nothing, previously sent both. The submitted mode now decides which values apply — and
  never clears a DOI already recorded on the work.
- **`a DOI-enabled form` and `a DataCite DOI-enabled form` assert round-tripping**, not
  delegation, and assert that `sync` returns the resource Hyrax's save step expects.
  Asserting delegation is what let the missing writer stay green.
- **A mint request for an unknown work answers 404 in JSON** rather than raising
  `Valkyrie::Persistence::ObjectNotFoundError` into a 500 with an HTML body, which the
  client — reading every response as JSON — could not report.
- **`doi_value=` tolerates an attribute that holds one value.** The
  `PersistentIdentifier` record is the source of truth and callers pass an array, which
  `Valkyrie::Types::Strict::String` rejects; the first value is written instead of the sync
  failing.
- **CI starts only the `web` service, and each shard gets its own Docker project.** `web`
  and `worker` share two volumes and both create the same directories in them at boot, so
  starting the pair raced and one died with `mkdir ...: file exists` — the container never
  came up, so no specs ran. Specs enqueue with the `:test` adapter and need no worker.
- **Both generators work on a Valkyrie application.** `hyrax:doi:install` wrote four
  registrar settings removed in this rewrite, so a freshly installed app raised on boot,
  and it injected a helper module the engine has wired itself since the DOI tab landed.
  `hyrax:doi:add_to_work_type` anchored its insertions on `include ::Hyrax::WorkBehavior`
  and `Hyrax::Forms::WorkForm`, neither of which a Valkyrie work type contains — and since
  `insert_into_file` only warns on a missing anchor, it reported success while changing
  nothing. It no longer touches presenters, because a Valkyrie work type has none.
- **`hyrax:doi:install` now installs the migration**, rather than leaving a separate step an
  adopter could miss and then hit as a missing-table error on first mint.
- **`hyrax:doi:migrations` runs at all.** Its template interpolated `migration_version`,
  which Rails does not supply to a plain generator, so it raised `NameError` instead of
  writing a migration. It had no spec; it does now.
- **The SolrDocument reads `doi_ssim`, not `doi_ssi`.** Nothing has ever written `doi_ssi`,
  so `solr_document.doi` returned nil for every work and the DOI never reached a show page.
  It also exposes `doi_state` now, which the renderer needs to suppress a draft.
- `doi_status` reads the state DataCite reported, falling back to the depositor's intent
  when nothing is registered yet, rather than recomputing state from intent and visibility.
- **`create_draft_doi` is a POST, not a GET**, and the controller renders JSON rather than
  executable JavaScript. Reserving an identifier has a side effect at DataCite, so a
  browser prefetch or a crawler must not be able to trigger it.
- **The DOI tab is organized around one choice.** It presented four controls in a flat list —
  two adjacently placed buttons both mentioning DOIs, and status options named only `Draft` /
  `Registered` / `Findable` — with nothing saying which combination a depositor wanted. It now
  offers three mutually exclusive situations (mint nothing, record a DOI the work already has,
  mint a new one) and reveals only the chosen one's controls, in CSS rather than JavaScript.
  Each minting option says what it does and whether it can be undone.
- **The DOI tab's inline `<script>` is gone**, replaced by `hyrax/doi/doi_form.js` —
  vanilla JS, event-delegated, reading `data-` attributes. The old handler used the
  jquery-ujs `ajax:beforeSend` signature `(e, xhr, settings)` while the stack ships
  rails-ujs, which passes a single event: `settings` was always undefined, so the DOI was
  never appended to the autofill request.
- **The missing-required-fields warning is data-driven.** It read four hardcoded selectors,
  including `.x_creator`, which silently matches nothing in a repository with no `creator`
  field — so the warning never fired there. The fields now come from the serializer.
- **Which DOI intents are offered depends on what DataCite reports**, not on the intent
  field. The old partial disabled options from `doi_status_when_public`, its own TODO noting
  it should use real DataCite state; that state now lives on the PID record.
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
- **Hyrax 5.3.0 or later is required in practice**, since the flexible metadata stack
  (`Hyrax::Flexibility`, `Hyrax::M3SchemaLoader`, `Hyrax::FlexibleSchema`, the
  `HYRAX_FLEXIBLE` config, and the `allinson` test app) first ships there and is absent from
  every earlier 5.x release.

  The gemspec nevertheless declares `hyrax >= 5.2`. The 5.3.0 version bump lives on the
  release commit, which was never merged back to `main`, so `main` carries the flexible
  stack while still declaring 5.2.0. A floor of 5.3 makes the gem unresolvable for any
  application tracking `main` — Hyku among them.
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

- `Hyrax::Renderers::DOIAttributeRenderer`, which links a DOI to its resolver on the show
  page and **withholds a draft**, since a draft is reserved but does not resolve — a linked
  one would be a dead link. It lives in Hyrax's namespace, and is named `DOI` rather than
  `Doi`, because `find_renderer_class` turns `render_as: doi` into a `Renderers.const_get`
  and the engine's `DOI` acronym inflection governs what that name camelizes to.
- `Hyrax::DOI::DOIResolver` and a working **Autofill from DOI** button, filling a deposit
  form from metadata already published for an existing DOI. This reads someone else's
  identifier to save retyping — it mints nothing, and a DOI recorded this way is
  `origin: external`, which the sync listener never pushes metadata to.

  Metadata comes from doi.org content negotiation as CSL JSON, so **any registration
  agency resolves, not just DataCite** — a CrossRef DOI for a published article is the
  common thing to paste. (DataCite's own media type returns 406 for a CrossRef DOI, which
  is why CSL JSON is the transport.) Only the `issued` date is read: CrossRef also sends
  `published`, `published-print`, and `published-online`, which disagree with each other.
  A partial date stays partial rather than being padded into a false full date.
- `Hyrax::DOI::PublisherListener`, keeping DataCite's copy of a work's metadata current.
  Subscribed to `object.metadata.updated` **and `object.acl.updated`**: embargo and lease
  release change permissions without saving metadata, so they publish only the latter, and
  a work whose intent is *findable* would otherwise sit at `registered` forever after
  release — exactly the case a depositor chose *findable* for.

  It only ever updates. Editing a work with no DOI mints nothing, and an identifier with
  `origin: external` is left alone, since it belongs to whoever issued it.
- A `mint` action, so a work deposited without a DOI can be given one. Requires edit
  permission on the work, and returns the DOI with the state DataCite reported.
- `app/views/hyrax/base/_show_action_mint_doi.html.erb`, the show-page button, contributed
  through Hyrax's `show_actions_for` helper so the gem overrides no view. That seam is new
  in Hyrax; on an earlier version nothing renders the partial, and an application wanting
  the button renders it directly.
- `DataCiteRegistrar.state_unreachable?`, which the form uses to close off intents a DOI
  can no longer reach. Past draft, DataCite transitions are one-way: a registered or
  findable DOI is a public promise that the identifier resolves, so it can be hidden but
  never withdrawn or returned to draft.
- `DataCiteSerializer.required_work_fields`, naming the work fields that feed DataCite's
  required set. Resolved through the profile mapping, so the form warns about the fields a
  repository actually uses.
- `MintButtonHelper#show_mint_doi_button?`, answering whether to offer minting on a show
  page from what a presenter exposes.
- The engine registers its own registrar and wires its own helpers, so installing the gem
  is enough. Hyrax ships an empty registrar hash, and the install generator only writes the
  registrar into a host initializer and the helpers into the host's `HyraxHelper` — easy to
  skip, and both minting and the DOI tab are then silently unavailable.
- `Hyrax::DOI::MintingPolicy`, deciding whether a work should get a DOI. The registrar
  consults it rather than checking inline, so a repository can restrict minting to
  particular work types:

  ```ruby
  Hyrax::DOI.configure do |config|
    config.minting_policy = Hyrax::DOI::MintingPolicy.new(work_types: %w[Dataset Monograph])
  end
  ```

  Defaults to any work type that names a registrar and whose depositor asked for a DOI.
  Naming a registrar is what a scheme concern adds, so it is a stronger signal than
  carrying the `doi_status_when_public` attribute, which a metadata profile could declare
  on a work type with nothing to mint through.
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

- **The ActiveFedora-era specs are gone**, rewritten against Valkyrie or removed where a
  Valkyrie spec already covered the same ground. Every one of them was excluded from every
  run, so none had executed since the port began — and each referenced code this rewrite
  removed (`GenericWork`, `Hyrax::GenericWorkForm`, `DataCiteRegistrar.prefix=`,
  `Bolognese::Metadata`, `HelperBehavior`), so none would have passed if re-enabled.

  One spec stays tagged: `add_to_work_type_generator_spec`, which drives the generator
  against a host `GenericWork`. The generators are rewritten for Valkyrie along with it.

  The shared examples that ship for adopters were rewritten too. `a DOI-enabled model` was
  asserting ActiveModel validations and `work.to_solr`, neither of which a Valkyrie
  resource has; it now checks the attribute and registrar contract, and the suite runs it
  so it cannot drift again.

### Removed

- **The `_attribute_rows.html.erb` override**, a copy of Hyrax 2.9's markup carried so that
  one line could add a DOI row. Hyrax's own partial is now driven by each field's `view:`
  block, so the copy was overriding profile-driven rendering with a hardcoded 2.9 field
  list — a work's own metadata profile decided nothing. The DOI row now comes from
  `config/metadata/doi.yaml`.
- **`Hyrax::DOI::WorkShowHelper` and `render_doi?`.** The renderer decides whether a DOI is
  shown, and `render_doi?` checked class ancestry, which a metadata profile does not touch.
- **`Hyrax::Actors::DOIActor` and the actor stack registration.** Hyrax's actor stack is
  deprecated in favor of transactions, and the actor's own `update` re-saved the work to
  force attribute persistence before enqueuing. A publisher listener needs neither.
- **`Hyrax::DOI::RegisterDOIJob`, replaced by `SyncDOIJob`.** It went through
  `Hyrax::Identifier::Dispatcher`, whose `assign_for` overwrites the identifier attribute,
  so a work could hold only one identifier — and it bypasses the transaction, so Solr was
  never reindexed. The new job takes a resource id rather than a serialized work: what to
  send DataCite is whatever is true when the job runs, and the provider comes from the
  identifier's own record, so a second provider needs no rewiring.
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
