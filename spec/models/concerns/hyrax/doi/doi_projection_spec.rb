# frozen_string_literal: true
require 'rails_helper'

# The PersistentIdentifier record is the source of truth; the work attribute is a
# projection of it, kept for indexing, display, and API compatibility. These cover
# reading the record through the work and syncing the projection back.
RSpec.describe 'deriving the work attribute from the PID record' do
  before do
    stub_const('ProjectionWork', Class.new(Hyrax::Work) do
      def self.name = 'ProjectionWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end)
  end

  let(:work) { ProjectionWork.new(id: 'work-1') }

  describe '#persistent_identifiers' do
    it 'is empty for a work with none' do
      expect(work.persistent_identifiers).to be_empty
    end

    it 'finds the records belonging to this work' do
      mine = Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-1', scheme: 'doi',
                                                      provider: 'datacite', value: '10.5072/mine',
                                                      origin: 'minted')
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'other-work', scheme: 'doi',
                                               provider: 'datacite', value: '10.5072/theirs',
                                               origin: 'minted')

      expect(work.persistent_identifiers).to contain_exactly(mine)
    end

    it 'is empty for an unsaved work with no id' do
      expect(ProjectionWork.new.persistent_identifiers).to be_empty
    end
  end

  describe '#doi_record' do
    it 'returns the primary doi-scheme record' do
      record = Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-1', scheme: 'doi',
                                                        provider: 'datacite', value: '10.5072/abc',
                                                        origin: 'minted')
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-1', scheme: 'raid',
                                               provider: 'datacite', value: '10.5072/raid',
                                               origin: 'minted')

      expect(work.doi_record).to eq record
    end

    it 'is nil when the work has no doi' do
      expect(work.doi_record).to be_nil
    end
  end

  describe '#sync_doi_projection!' do
    it 'copies the record value onto the work attribute' do
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-1', scheme: 'doi',
                                               provider: 'datacite', value: '10.5072/abc',
                                               origin: 'minted')

      work.sync_doi_projection!
      expect(work.doi_value).to eq ['10.5072/abc']
    end

    it 'clears the attribute when the record is gone' do
      work.doi_value = ['10.5072/stale']
      work.sync_doi_projection!
      expect(work.doi_value).to eq []
    end

    it 'writes through a configured attribute name' do
      stub_const('CustomProjectionWork', Class.new(Hyrax::Work) do
        def self.name = 'CustomProjectionWork'
        include Hyrax::DOI::DOIBehavior
        holds_doi_in :permalink
      end)
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-2', scheme: 'doi',
                                               provider: 'datacite', value: '10.5072/custom',
                                               origin: 'minted')

      custom = CustomProjectionWork.new(id: 'work-2')
      custom.sync_doi_projection!
      expect(custom.permalink).to eq ['10.5072/custom']
    end
  end

  describe '#doi_state' do
    it 'reports what the provider last told us, not the work intent' do
      work.doi_status_when_public = 'findable'
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: 'work-1', scheme: 'doi',
                                               provider: 'datacite', value: '10.5072/abc',
                                               origin: 'minted', state: 'registered')

      expect(work.doi_status_when_public).to eq 'findable'
      expect(work.doi_state).to eq 'registered'
    end

    it 'is nil without a record' do
      expect(work.doi_state).to be_nil
    end
  end
end
