# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::HyraxDOIController, type: :controller do
  routes { Hyrax::DOI::Engine.routes }

  let(:user) { create(:user) }
  let(:credentials) do
    Hyrax::DOI::Credentials.new(provider: 'datacite', prefix: '10.5072',
                                username: 'u', password: 'p', mode: 'test')
  end

  before do
    store = Class.new(Hyrax::DOI::CredentialStore) do
      def fetch(provider:)
        Hyrax::DOI::Credentials.new(provider: provider, prefix: '10.5072',
                                    username: 'u', password: 'p', mode: 'test')
      end
    end
    Hyrax::DOI.configure { |config| config.credential_store = store.new }
    allow_any_instance_of(Hyrax::Ability).to receive(:can_create_any_work?).and_return(true)
    sign_in user
  end

  after { Hyrax::DOI.reset_config! }

  describe 'POST #create_draft_doi' do
    let(:base) { 'https://api.test.datacite.org' }

    it 'returns the minted DOI as JSON' do
      stub_request(:post, "#{base}/dois")
        .to_return(status: 201, body: { data: { id: '10.5072/new-draft' } }.to_json)

      post :create_draft_doi, format: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['doi']).to eq '10.5072/new-draft'
    end

    it 'reports DataCite refusing without raising' do
      stub_request(:post, "#{base}/dois")
        .to_return(status: 422, body: { errors: [{ title: 'Prefix is not allowed' }] }.to_json)

      post :create_draft_doi, format: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to match(/Prefix is not allowed/)
    end

    it 'refuses when DOI minting is switched off' do
      allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(false)

      post :create_draft_doi, format: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body['error']).to be_present
    end

    it 'refuses a user who cannot deposit' do
      allow(controller.current_ability).to receive(:can_create_any_work?).and_return(false)

      post :create_draft_doi, format: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST #mint' do
    let(:work) { valkyrie_create(:hyrax_work, :public, title: ['Mintable']) }

    before do
      allow(Hyrax::DOI.config.minting_policy).to receive(:mintable?).and_return(true)
    end

    it 'refuses a user who cannot edit the work' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(false)

      post :mint, params: { id: work.id }, format: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'reports the registrar\'s failure rather than raising' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(errors: ['DataCite requires publisher'])
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)

      post :mint, params: { id: work.id }, format: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body['error']).to match(/publisher/)
    end

    it 'returns the DOI and its state on success' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(identifier: '10.5072/minted',
                                                  state: 'findable', changed: true)
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)

      post :mint, params: { id: work.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('doi' => '10.5072/minted', 'state' => 'findable')
    end
  end
end
