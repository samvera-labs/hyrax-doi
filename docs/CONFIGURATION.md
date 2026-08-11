# Configuration

Everything here is optional. A single-tenant application that sets the DataCite
environment variables and runs the generators needs none of it.

Configuration goes in `config/initializers/hyrax-doi.rb`, written by
`rails g hyrax:doi:install`.

## Where credentials come from

By default they are read from `DATACITE_PREFIX`, `DATACITE_USERNAME`,
`DATACITE_PASSWORD`, and `DATACITE_MODE`.

An application that already stores provider credentials — one per tenant, in Vault, in
Rails credentials — supplies its own store instead. The gem ships no persistence model on
purpose: a host that already has somewhere to keep these should not be given a second
place.

```ruby
class TenantCredentialStore < Hyrax::DOI::CredentialStore
  def fetch(provider:)
    endpoint = Account.current.datacite_endpoint
    Hyrax::DOI::Credentials.new(provider: provider,
                                prefix: endpoint.prefix,
                                username: endpoint.username,
                                password: endpoint.password,
                                mode: endpoint.mode)
  end
end

Hyrax::DOI.configure do |config|
  config.credential_store = TenantCredentialStore.new
end
```

`fetch` is called once per registration rather than cached, so a background job that has
switched tenants gets that tenant's credentials. This is why credentials must never be
passed through job arguments — only the tenant crosses the queue.

`Credentials` redacts itself in `inspect` and `to_s`, so a password cannot reach a log or
an exception report by accident.

### Describing a provider's fields

`Hyrax::DOI::CredentialStore.field_schema_for('datacite')` returns what the provider needs
— name, type, whether it is required, whether it is secret, and any fixed choices. An
admin form can render itself from this rather than hardcoding field names.

## Which work types may mint

By default, any work type that names a registrar and whose depositor asked for a DOI.
Naming a registrar is what `Hyrax::DOI::DataCiteDOIBehavior` adds, so a work type without
that concern is never eligible, whatever its metadata says.

To restrict further:

```ruby
Hyrax::DOI.configure do |config|
  config.minting_policy = Hyrax::DOI::MintingPolicy.new(work_types: %w[Dataset Monograph])
end
```

## Supplying fields DataCite requires

A registered or findable DOI needs `creators`, `titles`, `publisher`, `publicationYear`,
and a resource type. Which work field feeds which DataCite field is read from your m3
profile, so it can be changed without a deploy:

```yaml
contributor:
  datacite_mapping: creators
```

Some values have to be derived rather than mapped — a repository with no `creator` field
must build creators from its typed-role contributors, which no YAML key expresses. For
those, supply an extractor:

```ruby
Hyrax::DOI.configure do |config|
  # Names; the serializer wraps each one as a DataCite creator.
  config.creator_extractor = lambda do |work|
    Array(work.contributor).select { |c| c.role == 'author' }.map(&:display_name)
  end

  # A single DataCite publisher, so this one returns the hash itself.
  config.publisher_extractor = ->(_work) { { name: 'My Institution' } }
end
```

Each extractor is called with the work. Return anything blank — `nil`, `[]` — and the
serializer falls back to reading the mapped field.

`Hyrax::DOI::DataCiteSerializer#missing_required` reports which required fields a work
still cannot supply, which is what the deposit form warns about before saving.

## Holding the DOI somewhere other than `doi`

A work type that already has an `identifier` field can keep its DOI there:

```ruby
class Monograph < Hyrax::Work
  include Hyrax::DOI::DOIBehavior
  holds_doi_in :identifier
end
```

Read it back with `doi_value` regardless of the attribute's name. Where the work type
already declares the attribute — from a metadata profile, a YAML schema, or its own DOI
support — that declaration wins and the gem does not redeclare it.

## Which provider mints which scheme

One default per scheme, since the provider is an institutional decision rather than a
per-work editorial one:

```ruby
Hyrax::DOI.configure do |config|
  config.default_providers = { 'doi' => 'datacite' }
end
```

## Flexible metadata

Under `HYRAX_FLEXIBLE=true` the DOI fields come from your m3 profile rather than from a
work class. Add them with:

```bash
rails hyrax:doi:install_flexible_profile
```

Pass `CLASSES=Monograph,Image` to limit which work types receive them. The task writes a
**new** profile version rather than editing the current one, because saved works pin the
schema version they were created under.

The `doi` property must carry a non-empty `view:` block, or Hyrax drops it and the DOI
never renders on the show page:

```yaml
doi:
  view:
    render_as: doi
    html_dl: true
```

A profile validator warns when the property is missing, has no `view:` block, or is
available on no class the profile declares.

## Where identifiers are stored

Each identifier is a row in `hyrax_doi_persistent_identifiers`, carrying its scheme,
provider, value, the state the provider last reported, whether the gem minted it, and when
it last synced. A work's `doi` attribute is a projection of the primary row, kept so
indexing and display keep working.

Two columns matter when reading the data:

- **`state`** is the provider's own vocabulary, stored verbatim — DataCite's
  `draft`/`registered`/`findable`. It is not normalized across providers, because
  DataCite's `findable` and another agency's `public` do not mean the same thing.
- **`origin`** is `minted` or `external`. The gem only ever updates what it minted; an
  identifier recorded by autofill belongs to whoever issued it and is left alone.
