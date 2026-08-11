# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteRegistrar, 'credentials' do
  let(:credentials) do
    Hyrax::DOI::Credentials.new(provider: 'datacite', prefix: '10.5072',
                                username: 'REPO.TEST', password: 'secret', mode: 'test')
  end

  after { Hyrax::DOI.reset_config! }

  it 'takes credentials at construction' do
    registrar = described_class.new(credentials:)
    expect(registrar.credentials.prefix).to eq '10.5072'
  end

  it 'resolves them from the configured store when not given' do
    store = Class.new(Hyrax::DOI::CredentialStore) do
      def fetch(provider:)
        Hyrax::DOI::Credentials.new(provider:, prefix: '10.7777',
                                    username: 'u', password: 'p')
      end
    end
    Hyrax::DOI.configure { |config| config.credential_store = store.new }

    expect(described_class.new.credentials.prefix).to eq '10.7777'
  end

  it 'builds its identifier builder from the resolved prefix' do
    registrar = described_class.new(credentials:)
    expect(registrar.builder.prefix).to eq '10.5072'
  end

  it 'holds no class-level credential state' do
    %i[prefix username password mode].each do |attribute|
      expect(described_class).not_to respond_to("#{attribute}=")
    end
  end

  describe '#ping' do
    let(:heartbeat) { 'https://api.test.datacite.org/heartbeat' }
    let(:authenticated) { %r{\Ahttps://api\.test\.datacite\.org/dois} }

    def stub_reachable
      stub_request(:get, heartbeat).to_return(status: 200, body: 'OK')
    end

    it 'succeeds when DataCite is reachable and the credentials work' do
      stub_reachable
      stub_request(:get, authenticated).to_return(status: 200, body: '{"data":[]}')

      expect(described_class.new(credentials:).ping).to be_success
    end

    it 'reports a failure when DataCite is unreachable' do
      stub_request(:get, heartbeat).to_timeout
      result = described_class.new(credentials:).ping

      expect(result).not_to be_success
      expect(result.message).to be_present
    end

    # The heartbeat answers regardless of who is asking, so reachability alone would
    # report success for a wrong password.
    it 'reports a failure when the credentials are rejected' do
      stub_reachable
      stub_request(:get, authenticated).to_return(status: 401, body: '{}')

      result = described_class.new(credentials:).ping
      expect(result).not_to be_success
      expect(result.message).to match(/credential|reject|authoriz/i)
    end

    it 'distinguishes rejected credentials from an unreachable service' do
      stub_request(:get, heartbeat).to_timeout
      unreachable = described_class.new(credentials:).ping

      stub_reachable
      stub_request(:get, authenticated).to_return(status: 401, body: '{}')
      rejected = described_class.new(credentials:).ping

      expect(unreachable.message).not_to eq rejected.message
    end

    it 'reports incomplete credentials without calling out' do
      incomplete = Hyrax::DOI::Credentials.new(provider: 'datacite')
      result = described_class.new(credentials: incomplete).ping

      expect(result).not_to be_success
      expect(result.message).to match(/credential/i)
    end

    it 'uses the production host when configured for production' do
      stub_request(:get, 'https://api.datacite.org/heartbeat').to_return(status: 200, body: 'OK')
      stub_request(:get, %r{\Ahttps://api\.datacite\.org/dois}).to_return(status: 200, body: '{"data":[]}')
      production = credentials.with(mode: 'production')

      expect(described_class.new(credentials: production).ping).to be_success
    end
  end
end
