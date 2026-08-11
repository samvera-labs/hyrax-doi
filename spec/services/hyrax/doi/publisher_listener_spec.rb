# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::PublisherListener do
  subject(:listener) { described_class.new }

  let(:work) { valkyrie_create(:hyrax_work, title: ['Synced']) }

  before do
    allow(Hyrax::DOI::SyncDOIJob).to receive(:perform_later)
  end

  # Proves the engine's subscription, not just the listener: a correct listener that was
  # never subscribed would pass every example below.
  describe 'subscription' do
    it 'reacts to an event published through Hyrax' do
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                               resource_type: work.class.name,
                                               scheme: 'doi', provider: 'datacite',
                                               value: '10.5072/subscribed', state: 'registered',
                                               origin: 'minted', primary: true)

      Hyrax.publisher.publish('object.metadata.updated', object: work, user: nil)

      expect(Hyrax::DOI::SyncDOIJob).to have_received(:perform_later).with(work.id.to_s)
    end
  end

  describe '#on_object_metadata_updated' do
    context 'when the work already has a DOI' do
      before do
        Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                                 resource_type: work.class.name,
                                                 scheme: 'doi', provider: 'datacite',
                                                 value: '10.5072/synced', state: 'registered',
                                                 origin: 'minted', primary: true)
      end

      it 'enqueues a sync' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).to have_received(:perform_later).with(work.id.to_s)
      end
    end

    context 'when the work has no DOI and asked for none' do
      it 'does nothing, so editing a work never mints one by accident' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).not_to have_received(:perform_later)
      end
    end

    context 'when the work asked for a DOI it does not have yet' do
      let(:work) do
        Hyrax.persister.save(
          resource: DOIWork.new(title: ['Wants one'], doi_status_when_public: 'draft')
        )
      end

      it 'enqueues a sync so the DOI is minted' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).to have_received(:perform_later).with(work.id.to_s)
      end

      it 'does nothing when the policy excludes the work type' do
        Hyrax::DOI.configure do |config|
          config.minting_policy = Hyrax::DOI::MintingPolicy.new(work_types: ['SomethingElse'])
        end

        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).not_to have_received(:perform_later)
      end
    end

    context 'when the work saved with a DOI reserved before it existed' do
      let(:work) do
        Hyrax.persister.save(resource: DOIWork.new(title: ['Reserved'], doi: ['10.5072/reserved']))
      end

      before do
        Hyrax::DOI::PersistentIdentifier.create!(resource_id: nil, resource_type: nil,
                                                 scheme: 'doi', provider: 'datacite',
                                                 value: '10.5072/reserved', state: 'draft',
                                                 origin: 'minted', primary: true)
      end

      it 'claims the reservation for the work' do
        listener.on_object_metadata_updated(object: work)

        record = Hyrax::DOI::PersistentIdentifier.find_by(value: '10.5072/reserved')
        expect(record.resource_id).to eq work.id.to_s
        expect(record.resource_type).to eq work.class.name
      end

      it 'enqueues a sync, so DataCite gets the work-s metadata' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).to have_received(:perform_later).with(work.id.to_s)
      end

      it 'does not claim a reservation for a work holding a different DOI' do
        other = Hyrax.persister.save(
          resource: DOIWork.new(title: ['Unrelated'], doi: ['10.5072/unrelated'])
        )

        listener.on_object_metadata_updated(object: other)

        expect(Hyrax::DOI::PersistentIdentifier.find_by(value: '10.5072/reserved').resource_id)
          .to be_nil
      end
    end

    context 'when the DOI came from somewhere else' do
      before do
        Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                                 resource_type: work.class.name,
                                                 scheme: 'doi', provider: 'external',
                                                 value: '10.9999/theirs', state: nil,
                                                 origin: 'external', primary: true)
      end

      it 'leaves it alone rather than pushing metadata for an identifier we do not own' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).not_to have_received(:perform_later)
      end
    end
  end

  describe '#on_object_acl_updated' do
    let(:acl) { instance_double(Hyrax::AccessControlList, resource: work) }

    before do
      Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                               resource_type: work.class.name,
                                               scheme: 'doi', provider: 'datacite',
                                               value: '10.5072/embargoed', state: 'registered',
                                               origin: 'minted', primary: true)
    end

    it 'enqueues a sync when permissions change' do
      listener.on_object_acl_updated(acl:, result: :success)

      expect(Hyrax::DOI::SyncDOIJob).to have_received(:perform_later).with(work.id.to_s)
    end

    it 'ignores a failed ACL save' do
      listener.on_object_acl_updated(acl:, result: :failure)

      expect(Hyrax::DOI::SyncDOIJob).not_to have_received(:perform_later)
    end
  end
end
