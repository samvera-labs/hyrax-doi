# frozen_string_literal: true
module Hyrax
  module DOI
    # Pushes a work's current metadata to the provider holding its DOI.
    class SyncDOIJob < ApplicationJob
      queue_as Hyrax.config.ingest_queue_name

      # Takes an id rather than the work: the queue may hold this for a while, and the
      # metadata to send is whatever is true when the job runs, not when it was enqueued.
      #
      # @param resource_id [String]
      def perform(resource_id)
        record = Hyrax::DOI::PersistentIdentifier.primary_for(resource_id:,
                                                              scheme: 'doi')
        return unless record&.minted?

        work = Hyrax.query_service.find_by(id: resource_id)
        # Keyed on the record's own provider, so a work minted through a second provider
        # syncs back to that one rather than the configured default.
        Hyrax::Identifier::Registrar.for(record.provider.to_sym).register!(object: work)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        # The work was deleted between enqueue and run. The identifier outlives it by
        # design -- a DOI is a permanent promise -- so this is not a failure.
        nil
      end
    end
  end
end
