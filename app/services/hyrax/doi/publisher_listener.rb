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

      # Two reasons to sync: the work holds an identifier we minted and its metadata may have
      # changed, or the depositor asked for a DOI it does not have yet. An externally supplied
      # DOI belongs to whoever issued it, so it is never pushed.
      def sync(object)
        return if object.blank?

        record = Hyrax::DOI::PersistentIdentifier.primary_for(resource_id: object.id.to_s,
                                                              scheme: 'doi') ||
                 claim_reservation(object)
        return unless record&.minted? || awaiting_first_mint?(object, record)

        Hyrax::DOI::SyncDOIJob.perform_later(object.id.to_s)
      end

      # Choosing a status on the deposit form is the depositor asking for a DOI, so saving has
      # to act on it -- this is the explicit request, not minting as a side effect of an
      # ordinary edit. Asks the policy, so a work type the operator excluded still mints
      # nothing.
      def awaiting_first_mint?(object, record)
        record.nil? && Hyrax::DOI.config.minting_policy.mintable?(object)
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
