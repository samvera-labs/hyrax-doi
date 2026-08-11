# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteClient, 'REST v2' do
  subject(:client) do
    described_class.new(username: 'REPO.TEST', password: 'secret', prefix: '10.5072', mode: :test)
  end

  let(:base) { 'https://api.test.datacite.org' }
  let(:attributes) { { titles: [{ title: 'A Work' }], url: 'https://repo.example.edu/works/1' } }

  describe '#create_draft_doi' do
    it 'posts only a prefix, so DataCite assigns the suffix' do
      request = stub_request(:post, "#{base}/dois")
                .with(body: { data: { type: 'dois', attributes: { prefix: '10.5072' } } }.to_json)
                .to_return(status: 201, body: { data: { id: '10.5072/abc-123' } }.to_json)

      expect(client.create_draft_doi).to eq '10.5072/abc-123'
      expect(request).to have_been_requested
    end

    it 'raises with DataCite\'s own message when it refuses' do
      stub_request(:post, "#{base}/dois")
        .to_return(status: 422, body: { errors: [{ title: 'Prefix is not allowed' }] }.to_json)

      expect { client.create_draft_doi }
        .to raise_error(Hyrax::DOI::DataCiteClient::Error, /Prefix is not allowed/)
    end
  end

  describe '#put_doi' do
    # One idempotent call replaces the metadata/url/status sequence the MDS API needed.
    it 'sends attributes and no event for a draft' do
      request = stub_request(:put, "#{base}/dois/10.5072/abc")
                .with { |req| JSON.parse(req.body).dig('data', 'attributes').exclude?('event') }
                .to_return(status: 200, body: { data: { id: '10.5072/abc', attributes: { state: 'draft' } } }.to_json)

      client.put_doi('10.5072/abc', attributes:)
      expect(request).to have_been_requested
    end

    %w[register publish hide].each do |event|
      it "sends event #{event} when asked" do
        request = stub_request(:put, "#{base}/dois/10.5072/abc")
                  .with { |req| JSON.parse(req.body).dig('data', 'attributes', 'event') == event }
                  .to_return(status: 200, body: { data: { id: '10.5072/abc', attributes: { state: 'findable' } } }.to_json)

        client.put_doi('10.5072/abc', attributes:, event:)
        expect(request).to have_been_requested
      end
    end

    it 'returns the state DataCite reports rather than the state we asked for' do
      stub_request(:put, "#{base}/dois/10.5072/abc")
        .to_return(status: 200, body: { data: { id: '10.5072/abc', attributes: { state: 'registered' } } }.to_json)

      expect(client.put_doi('10.5072/abc', attributes:, event: 'publish').state).to eq 'registered'
    end

    it 'surfaces field-level validation errors' do
      stub_request(:put, "#{base}/dois/10.5072/abc")
        .to_return(status: 422,
                   body: { errors: [{ source: 'creators', title: 'cannot be blank' },
                                    { source: 'publisher', title: 'cannot be blank' }] }.to_json)

      expect { client.put_doi('10.5072/abc', attributes:) }
        .to raise_error(Hyrax::DOI::DataCiteClient::Error, /creators.*publisher/m)
    end
  end

  describe '#get_doi' do
    it 'reports the current state' do
      stub_request(:get, "#{base}/dois/10.5072/abc")
        .to_return(status: 200, body: { data: { id: '10.5072/abc', attributes: { state: 'findable' } } }.to_json)

      expect(client.get_doi('10.5072/abc').state).to eq 'findable'
    end

    it 'returns nil for a DOI DataCite does not have' do
      stub_request(:get, "#{base}/dois/10.5072/nope").to_return(status: 404, body: '{}')
      expect(client.get_doi('10.5072/nope')).to be_nil
    end
  end

  describe '#delete_doi' do
    it 'deletes a draft' do
      stub_request(:delete, "#{base}/dois/10.5072/abc").to_return(status: 204, body: '')
      expect(client.delete_doi('10.5072/abc')).to be true
    end

    # DataCite only permits deleting drafts; registered and findable DOIs are permanent.
    it 'raises when DataCite refuses to delete a registered DOI' do
      stub_request(:delete, "#{base}/dois/10.5072/abc")
        .to_return(status: 405, body: { errors: [{ title: 'Method not allowed' }] }.to_json)

      expect { client.delete_doi('10.5072/abc') }.to raise_error(Hyrax::DOI::DataCiteClient::Error)
    end
  end

  describe 'the legacy MDS API' do
    it 'is gone' do
      %i[put_metadata delete_metadata get_metadata get_url register_url delete_draft_doi].each do |method|
        expect(client).not_to respond_to(method)
      end
    end
  end

  describe 'connection reuse' do
    it 'builds one Faraday connection rather than one per call' do
      expect(client.send(:connection)).to be client.send(:connection)
    end
  end

  describe 'production mode' do
    subject(:client) do
      described_class.new(username: 'u', password: 'p', prefix: '10.5072', mode: :production)
    end

    it 'talks to the production host' do
      request = stub_request(:post, 'https://api.datacite.org/dois')
                .to_return(status: 201, body: { data: { id: '10.5072/x' } }.to_json)

      client.create_draft_doi
      expect(request).to have_been_requested
    end
  end
end
