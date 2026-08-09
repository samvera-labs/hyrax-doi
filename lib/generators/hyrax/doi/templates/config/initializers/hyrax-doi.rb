# frozen_string_literal: true
# The gem registers its own registrar, subscribes its own listener, and wires its own
# helpers, so nothing here is required to make DOIs work. Credentials come from
# DATACITE_PREFIX, DATACITE_USERNAME, DATACITE_PASSWORD, and DATACITE_MODE by default.
#
# Everything below is optional.

## A host for the URLs registered with the DOI, if Rails cannot infer one.
# Rails.application.routes.default_url_options[:host] = 'localhost:3000'

Hyrax::DOI.configure do |config|
  ## Where credentials are read from. The default reads the environment variables above;
  ## replace it to read from a tenant record, Rails credentials, or a secret store.
  # config.credential_store = MyCredentialStore.new

  ## Which work types may mint, and the state a DOI starts in. Defaults to any work type
  ## that names a registrar and whose depositor asked for a DOI.
  # config.minting_policy = Hyrax::DOI::MintingPolicy.new(work_types: %w[Dataset Monograph])

  ## Builds DataCite's `creators` for a repository whose works have no creator field.
  # config.creator_extractor = ->(work) { Array(work.contributor) }
end
