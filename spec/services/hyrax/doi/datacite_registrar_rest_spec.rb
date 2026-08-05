# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteRegistrar, 'registering' do
  before do
    stub_const('RegisteredWork', Class.new(Hyrax::Work) do
      def self.name = 'RegisteredWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
      attribute :creator, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :publisher, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :date_created, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :resource_type, Valkyrie::Types::Array.of(Valkyrie::Types::String)
    end)
    allow(Rails.application.routes.url_helpers).to receive(:polymorphic_url)
      .and_return('https://repo.example.edu/works/abc')
  end

  subject(:registrar) { described_class.new(credentials: credentials) }

  let(:credentials) do
    Hyrax::DOI::Credentials.new(provider: 'datacite', prefix: '10.5072',
                                username: 'u', password: 'p', mode: 'test')
  end

  # Visibility is derived from read_groups rather than stored, so it has to be assigned
  # after construction -- passing it to .new does nothing.
  let(:work) do
    RegisteredWork.new(id: 'abc', title: ['A Work'], creator: ['Smith, Jane'],
                       publisher: ['Example Library'], date_created: ['2026'],
                       resource_type: ['Dataset'], doi: ['10.5072/abc'],
                       doi_status_when_public: status).tap do |resource|
      resource.visibility = visibility
    end
  end

  let(:status) { 'draft' }
  let(:visibility) { 'open' }
  let(:base) { 'https://api.test.datacite.org' }

  def stub_put(state: 'draft')
    stub_request(:put, "#{base}/dois/10.5072/abc")
      .to_return(status: 200,
                 body: { data: { id: '10.5072/abc', attributes: { state: state } } }.to_json)
  end

  def event_sent
    body = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
                                   .find { |sig| sig.method == :put }&.body
    JSON.parse(body.to_s.presence || '{}').dig('data', 'attributes', 'event')
  end

  describe 'the event sent for each intent' do
    it 'sends no event for draft, leaving the DOI unpublished' do
      stub_put
      registrar.register!(object: work)
      expect(event_sent).to be_nil
    end

    context 'when the intent is registered' do
      let(:status) { 'registered' }

      it 'sends register' do
        stub_put(state: 'registered')
        registrar.register!(object: work)
        expect(event_sent).to eq 'register'
      end
    end

    context 'when the intent is findable and the work is public' do
      let(:status) { 'findable' }

      it 'sends publish' do
        stub_put(state: 'findable')
        registrar.register!(object: work)
        expect(event_sent).to eq 'publish'
      end
    end

    context 'when the intent is findable but the work is private' do
      let(:status) { 'findable' }
      let(:visibility) { 'restricted' }

      it 'sends hide, leaving the DOI resolvable but unindexed' do
        stub_put(state: 'registered')
        registrar.register!(object: work)
        expect(event_sent).to eq 'hide'
      end
    end
  end

  describe 'the result' do
    let(:status) { 'findable' }

    it 'reports the state DataCite gave back, not the state requested' do
      stub_put(state: 'registered')
      result = registrar.register!(object: work)

      expect(result.state).to eq 'registered'
      expect(result).to be_success
      expect(result).to be_changed
    end

    it 'carries the identifier' do
      stub_put(state: 'findable')
      expect(registrar.register!(object: work).identifier).to eq '10.5072/abc'
    end

    it 'reports DataCite\'s field-level errors rather than raising' do
      stub_request(:put, "#{base}/dois/10.5072/abc")
        .to_return(status: 422, body: { errors: [{ source: 'creators', title: 'cannot be blank' }] }.to_json)

      result = registrar.register!(object: work)
      expect(result).to be_failure
      expect(result.error_message).to match(/creators/)
    end
  end

  describe 'when nothing needs doing' do
    let(:status) { nil }

    it 'returns the existing DOI without calling DataCite' do
      result = registrar.register!(object: work)

      expect(result.identifier).to eq '10.5072/abc'
      expect(result).not_to be_changed
      expect(a_request(:put, %r{#{base}/dois})).not_to have_been_made
    end
  end

  describe 'when the work has no DOI yet' do
    let(:work) do
      RegisteredWork.new(id: 'abc', title: ['A Work'], creator: ['Smith, Jane'],
                         publisher: ['Example Library'], date_created: ['2026'],
                         resource_type: ['Dataset'], doi_status_when_public: 'draft')
    end

    it 'mints a draft first, then submits' do
      stub_request(:post, "#{base}/dois")
        .to_return(status: 201, body: { data: { id: '10.5072/new' } }.to_json)
      stub_request(:put, "#{base}/dois/10.5072/new")
        .to_return(status: 200, body: { data: { id: '10.5072/new', attributes: { state: 'draft' } } }.to_json)

      expect(registrar.register!(object: work).identifier).to eq '10.5072/new'
    end
  end

  describe 'when required metadata is missing' do
    let(:status) { 'findable' }
    let(:work) do
      RegisteredWork.new(id: 'abc', title: ['A Work'], doi: ['10.5072/abc'],
                         doi_status_when_public: 'findable')
    end

    # DataCite would reject this anyway; failing before the request names the fields.
    it 'says which fields are missing without calling DataCite' do
      result = registrar.register!(object: work)

      expect(result).to be_failure
      expect(result.error_message).to match(/publisher/)
      expect(a_request(:put, %r{#{base}/dois})).not_to have_been_made
    end
  end
end
