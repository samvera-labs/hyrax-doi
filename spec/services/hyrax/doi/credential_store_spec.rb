# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::CredentialStore do
  after { Hyrax::DOI.reset_config! }

  describe Hyrax::DOI::EnvCredentialStore do
    subject(:store) { described_class.new }

    around do |example|
      original = ENV.to_hash
      example.run
      ENV.replace(original)
    end

    it 'reads DataCite credentials from the environment' do
      ENV['DATACITE_PREFIX'] = '10.5072'
      ENV['DATACITE_USERNAME'] = 'REPO.TEST'
      ENV['DATACITE_PASSWORD'] = 'secret'
      ENV['DATACITE_MODE'] = 'production'

      credentials = store.fetch(provider: 'datacite')
      expect(credentials).to have_attributes(prefix: '10.5072', username: 'REPO.TEST',
                                             password: 'secret', mode: :production)
    end

    it 'returns incomplete credentials rather than nil when unset' do
      %w[DATACITE_PREFIX DATACITE_USERNAME DATACITE_PASSWORD].each { |key| ENV.delete(key) }

      credentials = store.fetch(provider: 'datacite')
      expect(credentials).not_to be_complete
      expect(credentials.mode).to eq :test
    end

    it 'is read-only' do
      expect { store.store(provider: 'datacite', attributes: {}) }
        .to raise_error(Hyrax::DOI::CredentialStore::ReadOnlyError)
    end
  end

  describe 'the configured store' do
    it 'defaults to the environment store' do
      expect(Hyrax::DOI.config.credential_store).to be_a Hyrax::DOI::EnvCredentialStore
    end

    it 'can be replaced by a host application' do
      custom = Class.new(Hyrax::DOI::CredentialStore) do
        def fetch(provider:)
          Hyrax::DOI::Credentials.new(provider:, prefix: '10.9999',
                                      username: 'u', password: 'p')
        end
      end

      Hyrax::DOI.configure { |config| config.credential_store = custom.new }
      expect(Hyrax::DOI.credentials_for('datacite').prefix).to eq '10.9999'
    end
  end

  # The bug this replaces -- see DataCiteRegistrar#initialize.
  describe 'thread isolation' do
    it 'gives concurrent threads their own credentials' do
      per_thread = Class.new(Hyrax::DOI::CredentialStore) do
        def fetch(provider:)
          Hyrax::DOI::Credentials.new(provider:, prefix: Thread.current[:doi_prefix],
                                      username: 'u', password: 'p')
        end
      end
      Hyrax::DOI.configure { |config| config.credential_store = per_thread.new }

      seen = {}
      threads = %w[10.1111 10.2222 10.3333].map do |prefix|
        Thread.new do
          Thread.current[:doi_prefix] = prefix
          sleep 0.01 # let the others interleave
          seen[prefix] = Hyrax::DOI.credentials_for('datacite').prefix
        end
      end
      threads.each(&:join)

      expect(seen).to eq('10.1111' => '10.1111', '10.2222' => '10.2222', '10.3333' => '10.3333')
    end
  end

  describe 'the provider field schema' do
    subject(:schema) { Hyrax::DOI::CredentialStore.field_schema_for('datacite') }

    it 'names the fields DataCite needs' do
      expect(schema.pluck(:name)).to eq %i[prefix username password mode]
    end

    it 'marks the password as secret so a form can mask it' do
      expect(schema.find { |field| field[:name] == :password }[:secret]).to be true
    end

    it 'offers the mode choices rather than free text' do
      expect(schema.find { |field| field[:name] == :mode }[:options]).to eq %w[test production]
    end

    it 'is empty for an unknown provider' do
      expect(Hyrax::DOI::CredentialStore.field_schema_for('nope')).to eq []
    end
  end
end
