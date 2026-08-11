# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::IdentifierRecorder do
  let(:work) { DOIWork.new(id: 'work-1', title: ['Moomin']) }

  describe '#record_minted' do
    it 'creates a row we may update at the provider' do
      recorder = described_class.new(scheme: 'doi', provider: 'datacite')
      record = recorder.record_minted(resource: work, value: '10.5072/minted', state: 'draft')

      expect(record).to be_persisted
      expect(record.origin).to eq Hyrax::DOI::PersistentIdentifier::MINTED
      expect(record.state).to eq 'draft'
      expect(record.resource_id).to eq 'work-1'
      expect(record.resource_type).to eq 'DOIWork'
    end

    it 'makes the DOI reachable through the work' do
      described_class.new(scheme: 'doi', provider: 'datacite')
                     .record_minted(resource: work, value: '10.5072/minted', state: 'registered')

      expect(work.doi_record&.value).to eq '10.5072/minted'
      expect(work.doi_state).to eq 'registered'
    end

    it 'updates the row rather than adding a second one for the same identifier' do
      recorder = described_class.new(scheme: 'doi', provider: 'datacite')
      recorder.record_minted(resource: work, value: '10.5072/same', state: 'draft')
      recorder.record_minted(resource: work, value: '10.5072/same', state: 'findable')

      expect(Hyrax::DOI::PersistentIdentifier.for_resource('work-1').count).to eq 1
      expect(work.doi_state).to eq 'findable'
    end
  end

  describe '#record_external' do
    it 'marks a DOI someone else minted so it is never updated at the provider' do
      record = described_class.new(scheme: 'doi', provider: 'datacite')
                              .record_external(resource: work, value: '10.5072/theirs')

      expect(record.origin).to eq Hyrax::DOI::PersistentIdentifier::EXTERNAL
      expect(record).not_to be_minted
      expect(record.state).to be_nil
    end
  end

  # A draft reserved from the deposit form exists before the work does, so it cannot carry a
  # resource_id yet. Without this the DOI is an orphan at DataCite with no local trace.
  describe '#record_reservation' do
    it 'records a draft that has no work yet' do
      record = described_class.new(scheme: 'doi', provider: 'datacite')
                              .record_reservation(value: '10.5072/reserved')

      expect(record.resource_id).to be_nil
      expect(record.state).to eq 'draft'
      expect(Hyrax::DOI::PersistentIdentifier.unattached).to include(record)
    end

    it 'attaches the reservation to the work that ends up using it' do
      recorder = described_class.new(scheme: 'doi', provider: 'datacite')
      recorder.record_reservation(value: '10.5072/reserved')
      recorder.record_minted(resource: work, value: '10.5072/reserved', state: 'draft')

      expect(Hyrax::DOI::PersistentIdentifier.where(value: '10.5072/reserved').count).to eq 1
      expect(work.doi_record&.resource_id).to eq 'work-1'
    end
  end
end
