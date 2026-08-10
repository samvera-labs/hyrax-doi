# frozen_string_literal: true
module Hyrax
  module DOI
    # Keeps DataCite's copy of a work's metadata current. Creation is always explicit, so
    # the only automatic work is updating identifiers that already exist.
    class PublisherListener
      # @param event [Dry::Events::Event]
      def on_object_metadata_updated(event)
        sync(event[:object])
      end

      # Embargo and lease release change permissions without saving metadata, so they
      # publish this and never object.metadata.updated. A work whose intent is findable
      # sits at registered while private; without this it would stay there after release.
      #
      # @param event [Dry::Events::Event]
      def on_object_acl_updated(event)
        return unless event[:result] == :success

        sync(event[:acl].resource)
      end

      private

      # Guarded on an identifier we minted: editing a work with no DOI must never create
      # one, and an externally supplied DOI belongs to whoever issued it.
      def sync(object)
        return if object.blank?

        record = Hyrax::DOI::PersistentIdentifier.primary_for(resource_id: object.id.to_s,
                                                              scheme: 'doi') ||
                 claim_reservation(object)
        return unless record&.minted?

        Hyrax::DOI::SyncDOIJob.perform_later(object.id.to_s)
      end

      # A DOI reserved from the deposit form is recorded before the work exists, so its row
      # carries no resource_id. The first save holding that DOI is what links the two --
      # without it nothing connects the work to its identifier, so no metadata is ever
      # pushed and the orphan sweep sees a reservation that was in fact used.
      #
      # @return [Hyrax::DOI::PersistentIdentifier, nil]
      def claim_reservation(object)
        value = Array.wrap(object.try(:doi_value)).compact_blank.first
        return if value.blank?

        record = Hyrax::DOI::PersistentIdentifier.unattached
                                                 .with_scheme('doi')
                                                 .find_by(value:)
        return if record.blank?

        record.update!(resource_id: object.id.to_s, resource_type: object.class.name)
        record
      end
    end
  end
end
