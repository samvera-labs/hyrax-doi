# frozen_string_literal: true
require 'rails_helper'

describe Bolognese::Readers::HyraxWorkReader do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior

      # Defined here for resourceType
      def self.name
        "WorkWithDOI"
      end
    end
  end
  let(:work) { model_class.create(attributes) }
  let(:attributes) do
    {
      title: [title],
      creator: [creator],
      publisher: [publisher],
      description: [description],
      doi: [doi]
    }
  end
  let(:title) { 'Moomin' }
  let(:creator) { 'Tove Jansson' }
  let(:publisher) { 'Schildts' }
  let(:description) { 'Swedish comic about the adventures of the residents of Moominvalley.' }
  let(:doi) { '10.18130/v3-k4an-w022' }
  let(:metadata_class) do
    Class.new(Bolognese::Metadata) do
      include Bolognese::Readers::HyraxWorkReader
    end
  end
  let(:input) { work.attributes.merge(has_model: work.has_model.first).to_json }

  it 'reads a GenericWork' do
    expect(metadata_class.new(input: input, from: 'hyrax_work')).to be_a Bolognese::Metadata
  end

  context 'publisher' do
    let(:metadata) { metadata_class.new(input: input, from: 'hyrax_work') }
    let(:attributes) do
      {
        title: [title],
        creator: [creator],
        publisher: [],
        description: [description],
        doi: [doi]
      }
    end

    it 'gives a default value of unavailable' do
      expect(metadata.publisher).to eq ':unav'
    end
  end

  context 'crosswalks' do
    let(:metadata) { metadata_class.new(input: input, from: 'hyrax_work') }

    context 'datacite' do
      subject(:datacite_xml) { Nokogiri::XML(datacite_string, &:strict).remove_namespaces! }
      let(:datacite_string) { metadata.datacite }

      it 'creates datacite XML' do
        expect(datacite_string).to be_a String
        expect(datacite_xml).to be_a Nokogiri::XML::Document
      end

      it 'sets the DOI' do
        expect(datacite_xml.xpath('/resource/identifier[@identifierType="DOI"]/text()').to_s).to eq "https://doi.org/#{doi}"
      end

      it 'correctly populates the datacite XML' do
        expect(datacite_xml.xpath('/resource/titles/title[1]/text()').to_s).to eq title
        expect(datacite_xml.xpath('/resource/creators/creator[1]/creatorName/text()').to_s).to eq creator
        expect(datacite_xml.xpath('/resource/publisher/text()').to_s).to eq publisher
        expect(datacite_xml.xpath('/resource/descriptions/description[1]/text()').to_s).to eq description
        expect(datacite_xml.xpath('/resource/publicationYear/text()').to_s).to eq "2020"
      end

      it 'sets the hyrax work type' do
        expect(datacite_xml.xpath('/resource/resourceType[@resourceTypeGeneral="Other"]/text()').to_s).to eq 'WorkWithDOI'
      end
    end
  end
end
