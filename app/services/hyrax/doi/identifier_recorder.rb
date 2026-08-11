# frozen_string_literal: true
module Hyrax
  module DOI
    # Writes PersistentIdentifier rows, which are the source of truth for what a resource's
    # identifiers are and what the provider last reported about them. The resource's own DOI
    # attribute is a projection kept in step here.
    #
    # Separate from the registrar because recording is not minting: a DOI a depositor pasted
    # in was minted by someone else and must be recorded without any provider call.
    class IdentifierRecorder
      def initialize(scheme:, provider:)
        @scheme = scheme.to_s
        @provider = provider.to_s
      end

      attr_reader :scheme, :provider

      ##
      # An identifier this repository created, so it may be updated at the provider.
      #
      # @param state [String, nil] provider vocabulary, stored verbatim
      # @return [Hyrax::DOI::PersistentIdentifier]
      def record_minted(resource:, value:, state: nil)
        write(resource:, value:, origin: PersistentIdentifier::MINTED, state:)
      end

      ##
      # An identifier someone else created. Carries no state: what a DOI we did not mint is
      # doing at its provider is not ours to track, and never ours to change.
      #
      # @return [Hyrax::DOI::PersistentIdentifier]
      def record_external(resource:, value:)
        write(resource:, value:, origin: PersistentIdentifier::EXTERNAL, state: nil)
      end

      ##
      # A draft reserved from the deposit form, before the work it belongs to exists. Left
      # unattached until a save claims it, so an abandoned form leaves a record to sweep
      # rather than an orphan known only to DataCite.
      #
      # @return [Hyrax::DOI::PersistentIdentifier]
      def record_reservation(value:, state: 'draft')
        write(resource: nil, value:, origin: PersistentIdentifier::MINTED, state:)
      end

      private

      # Found by value rather than by resource: the same identifier may arrive first as an
      # unattached reservation and again once the work exists, and it is one identifier
      # either way. The unique index is on (scheme, provider, value).
      def write(resource:, value:, origin:, state:)
        record = PersistentIdentifier.find_or_initialize_by(scheme:, provider:, value: value.to_s)
        record.origin = origin
        record.state = state if state
        record.primary = true if record.new_record?
        record.minted_at ||= Time.current if origin == PersistentIdentifier::MINTED
        attach(record, resource)
        record.save!
        project_onto(resource, record)
        record
      end

      def attach(record, resource)
        return if resource.blank? || resource.id.blank?

        record.resource_id = resource.id.to_s
        record.resource_type = resource.class.name
      end

      # Keeps the resource's DOI attribute in step so indexing and the show page see the
      # identifier without querying this table. Only for the doi scheme -- a RAiD or an ORCID
      # has no such attribute to project onto.
      def project_onto(resource, record)
        return unless scheme == 'doi'
        return unless resource.respond_to?(:doi_value=)
        return unless record.primary?

        resource.doi_value = [record.value]
      end
    end
  end
end
