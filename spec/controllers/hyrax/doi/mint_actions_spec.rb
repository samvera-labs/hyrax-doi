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
        Hyrax::DOI::Credentials.new(provider:, prefix: '10.5072',
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

    # Without a local record the reserved DOI exists only at DataCite, so an abandoned form
    # leaves an orphan nothing can find again.
    it 'records the reservation so it is not an orphan' do
      stub_request(:post, "#{base}/dois")
        .to_return(status: 201, body: { data: { id: '10.5072/new-draft' } }.to_json)

      post :create_draft_doi, format: :json

      record = Hyrax::DOI::PersistentIdentifier.find_by(value: '10.5072/new-draft')
      expect(record).to be_present
      expect(record.state).to eq 'draft'
      expect(record.resource_id).to be_nil
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

    # The client reads every response as JSON, so an unknown id has to answer in JSON
    # rather than raise into Rails' HTML error page.
    it 'reports an unknown work as JSON, not a 500' do
      post :mint, params: { id: 'no-such-work' }, format: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to be_present
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

    it 'records the DOI against the work so later edits can sync it' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(identifier: '10.5072/minted',
                                                  state: 'findable', changed: true)
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)

      post :mint, params: { id: work.id }, format: :json

      record = Hyrax::DOI::PersistentIdentifier.primary_for(resource_id: work.id.to_s, scheme: 'doi')
      expect(record&.value).to eq '10.5072/minted'
      expect(record).to be_minted
      expect(record.state).to eq 'findable'
    end

    it 'stores the DOI on the work itself, so it indexes and displays' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(identifier: '10.5072/minted',
                                                  state: 'findable', changed: true)
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)
      doi_work = Hyrax.persister.save(resource: DOIWork.new(title: ['Holds a DOI']))

      post :mint, params: { id: doi_work.id }, format: :json

      expect(Array(Hyrax.query_service.find_by(id: doi_work.id).doi)).to eq ['10.5072/minted']
    end

    # A repository may enable minting for a work type the gem's concern was never added to.
    it 'still answers for a work that has no DOI attribute to project onto' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(identifier: '10.5072/minted',
                                                  state: 'findable', changed: true)
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)

      post :mint, params: { id: work.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(Hyrax::DOI::PersistentIdentifier.for_resource(work.id.to_s)).not_to be_empty
    end

    it 'does not record anything when the registrar failed' do
      allow(controller.current_ability).to receive(:can?).with(:edit, anything).and_return(true)
      result = Hyrax::DOI::RegistrationResult.new(errors: ['DataCite requires publisher'])
      allow_any_instance_of(Hyrax::DOI::DataCiteRegistrar).to receive(:register!).and_return(result)

      post :mint, params: { id: work.id }, format: :json

      expect(Hyrax::DOI::PersistentIdentifier.for_resource(work.id.to_s)).to be_empty
    end
  end

  describe 'GET #autofill' do
    it 'returns the attributes a form can apply' do
      stub_request(:get, 'https://doi.org/10.1234/found')
        .to_return(status: 200,
                   body: { 'title' => 'Found', 'issued' => { 'date-parts' => [[2020]] } }.to_json)

      get :autofill, params: { doi: '10.1234/found' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['attributes'])
        .to include('title' => ['Found'], 'date_created' => ['2020'])
    end

    it 'reports a DOI that does not resolve' do
      stub_request(:get, 'https://doi.org/10.1234/missing').to_return(status: 404)

      get :autofill, params: { doi: '10.1234/missing' }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'distinguishes a resolver outage from a missing DOI' do
      stub_request(:get, 'https://doi.org/10.1234/down').to_return(status: 503)

      get :autofill, params: { doi: '10.1234/down' }, format: :json

      expect(response).to have_http_status(:bad_gateway)
    end

    it 'refuses a user who cannot deposit' do
      allow(controller.current_ability).to receive(:can_create_any_work?).and_return(false)

      get :autofill, params: { doi: '10.1234/found' }, format: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
