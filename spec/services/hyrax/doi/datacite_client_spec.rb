# frozen_string_literal: true
require 'rails_helper'
require 'support/datacite_api_stubs'

describe 'Hyrax::DOI::DataciteClient', :datacite_api do
  let(:client) { Hyrax::DOI::DataciteClient.new(username: username, password: password, prefix: prefix, mode: :test) }
  let(:username) { 'username' }
  let(:password) { 'password' }
  let(:prefix) { '10.1234' }
  let(:draft_doi) { "#{prefix}/draft-doi" }
  let(:findable_doi) { "#{prefix}/findable-doi" }
  let(:unknown_doi) { "#{prefix}/unknown-doi" }

  describe '#create_draft_doi' do
    it 'creates a DOI' do
      expect(client.create_draft_doi).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
    end

    context 'with incorrect credentials' do
      let(:username) { 'bad-username' }
      let(:password) { 'bad-password' }

      it 'raises error with bad credentials' do
        expect { client.create_draft_doi }.to raise_error(/Failed creating draft DOI/)
      end
    end
  end

  describe '#delete_draft_doi' do
    it 'deletes a draft DOI' do
      expect(client.delete_draft_doi(draft_doi)).to eq draft_doi
    end

    it 'errors with a registered or findable DOI' do
      expect { client.delete_draft_doi(findable_doi) }.to raise_error(/Failed deleting draft DOI/)
    end
  end

  describe '#get_metadata' do
    it 'returns metadata' do
      response = client.get_metadata(draft_doi)
      expect(response).to be_a Nokogiri::XML::Document
      expect(response.xpath('//identifier[@identifierType="DOI"]/text()').first.to_s).to eq draft_doi
    end

    it 'errors with unknown DOI' do
      expect { client.get_metadata(unknown_doi) }.to raise_error(/Failed getting DOI metadata/)
    end
  end

  describe '#put_metadata' do
    let(:metadata) do
      <<-XML.chomp
        <?xml version="1.0" encoding="UTF-8"?>
        <resource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://datacite.org/schema/kernel-4" xsi:schemaLocation="http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4/metadata.xsd">
          <identifier identifierType="DOI">#{doi}</identifier>
          <creators>
            <creator>
              <creatorName>Chris Colvard</creatorName>
            </creator>
          </creators>
          <titles>
            <title>Test datacite registration work</title>
          </titles>
          <publisher>Ubiquity Press</publisher>
          <publicationYear>2020</publicationYear>
          <resourceType resourceTypeGeneral="Other">GenericWork</resourceType>
          <sizes/>
          <formats/>
          <version/>
        </resource>
      XML
    end
    let(:doi) { draft_doi }

    context 'when doi param is blank' do
      let(:doi) { prefix }

      it 'creates a doi' do
        expect(client.put_metadata(nil, metadata)).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
      end
    end

    it 'returns the same doi' do
      expect(client.put_metadata(draft_doi, metadata)).to eq draft_doi
    end

    context 'with unknown doi' do
      let(:prefix) { 'unknown-prefix' }
      it 'errors with unknown DOI' do
        expect { client.put_metadata(unknown_doi, metadata) }.to raise_error(/Failed creating metadata for DOI/)
      end
    end
  end

  describe '#delete_metadata' do
    it 'returns the passed doi' do
      expect(client.delete_metadata(draft_doi)).to eq draft_doi
    end

    context 'with incorrect credentials' do
      let(:username) { 'bad-username' }
      let(:password) { 'bad-password' }

      it 'raises error with bad credentials' do
        expect { client.delete_metadata(draft_doi) }.to raise_error(/Failed deleting DOI metadata/)
      end
    end
  end

  describe '#get_url' do
    it 'returns url' do
      expect(URI.parse(client.get_url(draft_doi))).to be_a URI::HTTP
    end

    it 'errors with unknown DOI' do
      expect { client.get_url(unknown_doi) }.to raise_error(/Failed getting DOI url/)
    end
  end

  describe '#register_url' do
    let(:url) { 'https://www.moomin.com/en/' }

    it 'returns the url when successful' do
      expect(client.register_url(draft_doi, url)).to eq url
    end

    it 'errors with unknown DOI' do
      expect { client.register_url(unknown_doi, url) }.to raise_error(/Failed registering url for DOI/)
    end
  end
end
