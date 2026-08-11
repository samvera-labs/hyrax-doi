# frozen_string_literal: true
module Hyrax
  module DOI
    # Pushes a work's current metadata to the provider holding its DOI, and mints one for a
    # work whose depositor asked for a DOI it does not have yet.
    class SyncDOIJob < ApplicationJob
      queue_as Hyrax.config.ingest_queue_name

      # Takes an id rather than the work: the queue may hold this for a while, and the
      # metadata to send is whatever is true when the job runs, not when it was enqueued.
      #
      # @param resource_id [String]
      def perform(resource_id)
        record = Hyrax::DOI::PersistentIdentifier.primary_for(resource_id:, scheme: 'doi')
        return if record.present? && !record.minted?

        work = Hyrax.query_service.find_by(id: resource_id)
        return if record.nil? && !mintable_and_unminted?(work)

        # Keyed on the record's own provider where one exists, so a work minted through a
        # second provider syncs back to that one rather than the configured default.
        provider = record&.provider || Hyrax::DOI.config.provider_for('doi')
        result = Hyrax::Identifier::Registrar.for(provider.to_sym).register!(object: work)
        record_result(work, provider, result)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        # The work was deleted between enqueue and run. The identifier outlives it by
        # design -- a DOI is a permanent promise -- so this is not a failure.
        nil
      end

      private

      # Minting creates a permanent identifier, so running twice must not produce two. The
      # work's own DOI is checked as well as the identifier record: a duplicate enqueue, a
      # retry, or two workers taking the same job would each otherwise see no record and mint.
      def mintable_and_unminted?(work)
        return false if Array.wrap(work.try(:doi_value)).compact_blank.any?

        Hyrax::DOI.config.minting_policy.mintable?(work)
      end

      # Writes back what the provider reported, so a first mint is recorded rather than
      # existing only at DataCite -- otherwise the next save mints a second one and nothing
      # local can find the first.
      def record_result(work, provider, result)
        return if result.blank? || result.identifier.blank?
        return unless result.success?

        Hyrax::DOI::IdentifierRecorder
          .new(scheme: 'doi', provider:)
          .record_minted(resource: work, value: result.identifier, state: result.state)
        Hyrax.persister.save(resource: work) if work.respond_to?(:doi_value=)
      end
    end
  end
end
