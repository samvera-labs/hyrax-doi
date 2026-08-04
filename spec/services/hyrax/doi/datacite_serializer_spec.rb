# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteSerializer do
  before do
    stub_const('SerializedWork', Class.new(Hyrax::Work) do
      def self.name = 'SerializedWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
      attribute :creator, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :publisher, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :date_created, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :resource_type, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :description, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :keyword, Valkyrie::Types::Array.of(Valkyrie::Types::String)
      attribute :contributor, Valkyrie::Types::Array.of(Valkyrie::Types::String)
    end)
  end

  let(:work) do
    SerializedWork.new(title: ['Example Work'], creator: ['Smith, Jane'],
                       publisher: ['Example University Library'],
                       date_created: ['2026-03-15'], resource_type: ['Dataset'])
  end

  let(:url) { 'https://repo.example.edu/concern/serialized_works/abc123' }

  subject(:payload) { described_class.new(work, url: url).to_attributes }

  after { Hyrax::DOI.reset_config! }

  describe 'the fields DataCite requires' do
    it 'includes titles' do
      expect(payload[:titles]).to eq [{ title: 'Example Work' }]
    end

    it 'includes creators' do
      expect(payload[:creators]).to eq [{ name: 'Smith, Jane' }]
    end

    it 'includes publisher' do
      expect(payload[:publisher]).to eq({ name: 'Example University Library' })
    end

    it 'reduces a date to a publication year' do
      expect(payload[:publicationYear]).to eq 2026
    end

    it 'includes a resourceTypeGeneral' do
      expect(payload.dig(:types, :resourceTypeGeneral)).to be_present
    end

    it 'includes the url' do
      expect(payload[:url]).to eq url
    end
  end

  describe 'optional fields' do
    it 'includes descriptions when present' do
      work.description = ['An abstract.']
      expect(payload[:descriptions]).to eq [{ description: 'An abstract.', descriptionType: 'Abstract' }]
    end

    it 'includes subjects when present' do
      work.keyword = %w[alpha beta]
      expect(payload[:subjects]).to eq [{ subject: 'alpha' }, { subject: 'beta' }]
    end

    it 'omits keys the work has no values for' do
      expect(payload).not_to have_key(:descriptions)
      expect(payload).not_to have_key(:subjects)
    end
  end

  # ':unav' is DataCite's own sentinel for an unavailable value, and creators is required,
  # so omitting it is not an option.
  describe 'when the work has no creator' do
    let(:work) { SerializedWork.new(title: ['No Creator']) }

    it 'falls back to the unavailable sentinel rather than omitting creators' do
      expect(payload[:creators]).to eq [{ name: ':unav' }]
    end
  end

  describe 'a configurable extractor' do
    it 'takes precedence over the default reading' do
      Hyrax::DOI.configure do |config|
        config.creator_extractor = ->(_work) { [{ name: 'Derived, Author' }] }
      end

      expect(payload[:creators]).to eq [{ name: 'Derived, Author' }]
    end

    it 'can supply the publisher too' do
      Hyrax::DOI.configure do |config|
        config.publisher_extractor = ->(_work) { { name: 'Tenant Name' } }
      end

      expect(payload[:publisher]).to eq({ name: 'Tenant Name' })
    end
  end

  describe 'reading datacite_mapping from the m3 profile' do
    it 'takes the source field named by the profile' do
      allow(Hyrax::DOI::DataCiteSerializer).to receive(:profile_mapping)
        .and_return('creators' => :contributor)
      work.contributor = ['Mapped, Person']

      expect(payload[:creators]).to eq [{ name: 'Mapped, Person' }]
    end

    it 'falls back to the conventional field when the profile says nothing' do
      allow(Hyrax::DOI::DataCiteSerializer).to receive(:profile_mapping).and_return({})
      expect(payload[:creators]).to eq [{ name: 'Smith, Jane' }]
    end
  end

  describe 'missing required metadata' do
    let(:work) { SerializedWork.new(title: ['Only a title']) }

    it 'reports which fields a registered or findable DOI would still need' do
      missing = described_class.new(work, url: url).missing_required
      expect(missing).to include('publisher')
    end

    it 'reports nothing missing for a complete work' do
      complete = SerializedWork.new(title: ['T'], creator: ['C'], publisher: ['P'],
                                    date_created: ['2026'], resource_type: ['Dataset'])
      expect(described_class.new(complete, url: url).missing_required).to be_empty
    end
  end
end
