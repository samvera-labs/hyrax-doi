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

    context 'when the work has no DOI' do
      it 'does nothing, so editing a work never mints one by accident' do
        listener.on_object_metadata_updated(object: work)

        expect(Hyrax::DOI::SyncDOIJob).not_to have_received(:perform_later)
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
