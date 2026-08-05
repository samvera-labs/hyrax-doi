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
                                                              scheme: 'doi')
        return unless record&.minted?

        Hyrax::DOI::SyncDOIJob.perform_later(object.id.to_s)
      end
    end
  end
end
