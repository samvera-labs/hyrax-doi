# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::Indexers::DOIIndexer do
  before do
    stub_const('IndexedDOIWork', Class.new(Hyrax::Work) do
      def self.name = 'IndexedDOIWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end)

    stub_const('IndexedDOIWorkIndexer', Class.new(Hyrax::Indexers::PcdmObjectIndexer(IndexedDOIWork)) do
      include Hyrax::DOI::Indexers::DOIIndexer
    end)
  end

  let(:work) { IndexedDOIWork.new(id: 'indexed-1') }
  let(:document) { IndexedDOIWorkIndexer.new(resource: work).to_solr }

  it 'indexes the doi' do
    work.doi_value = ['10.5072/abc']
    expect(document['doi_ssim']).to eq ['10.5072/abc']
    expect(document['doi_tesim']).to eq ['10.5072/abc']
  end

  it 'indexes the intent and the provider state separately' do
    work.doi_status_when_public = 'findable'
    Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'indexed-1', scheme: 'doi',
                                             provider: 'datacite', value: '10.5072/abc',
                                             origin: 'minted', state: 'registered')

    expect(document['doi_status_when_public_ssi']).to eq 'findable'
    expect(document['doi_state_ssi']).to eq 'registered'
  end

  it 'emits empty values rather than failing for a work with no doi' do
    expect(document['doi_ssim']).to eq []
    expect(document['doi_state_ssi']).to be_nil
  end

  it 'reads through a configured attribute name' do
    stub_const('CustomIndexedWork', Class.new(Hyrax::Work) do
      def self.name = 'CustomIndexedWork'
      include Hyrax::DOI::DOIBehavior
      holds_doi_in :permalink
    end)
    stub_const('CustomIndexedWorkIndexer', Class.new(Hyrax::Indexers::PcdmObjectIndexer(CustomIndexedWork)) do
      include Hyrax::DOI::Indexers::DOIIndexer
    end)

    custom = CustomIndexedWork.new(permalink: ['10.5072/custom'])
    expect(CustomIndexedWorkIndexer.new(resource: custom).to_solr['doi_ssim']).to eq ['10.5072/custom']
  end

  it 'leaves keys a schema loader already supplied' do
    indexer_class = Class.new(Hyrax::Indexers::PcdmObjectIndexer(IndexedDOIWork)) do
      include Hyrax::DOI::Indexers::DOIIndexer

      def to_solr(*args)
        super.tap { |doc| doc['doi_ssim'] ||= ['from-schema'] }
      end
    end

    work.doi_value = ['10.5072/abc']
    # The mixin runs first via super, so its value stands.
    expect(indexer_class.new(resource: work).to_solr['doi_ssim']).to eq ['10.5072/abc']
  end

  it 'is inert on a resource without the concern' do
    plain = Class.new(Hyrax::Work) { def self.name = 'PlainWork' }
    indexer = Class.new(Hyrax::Indexers::PcdmObjectIndexer(plain)) do
      include Hyrax::DOI::Indexers::DOIIndexer
    end

    expect { indexer.new(resource: plain.new).to_solr }.not_to raise_error
  end
end
