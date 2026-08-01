# frozen_string_literal: true
module Hyrax
  module DOI
    class DataCiteRegistrar < Hyrax::Identifier::Registrar
      STATES = %w[draft registered findable].freeze

      # FIXME: make this configurable in a different way so tenants can have different configs in Hyku
      class_attribute :prefix, :username, :password, :mode

      def initialize(builder: Hyrax::Identifier::Builder.new(prefix: self.prefix))
        super
      end

      ##
      # @param object [#id]
      #
      # @return [#identifier]
      def register!(object: work)
        doi = Array(object.try(:doi)).first

        # Return the existing DOI or nil if nothing needs to be done
        return Struct.new(:identifier).new(doi) unless register?(object)

        # Create a draft DOI (if necessary)
        doi ||= mint_draft_doi

        # Submit metadata, register url, and ensure proper status
        submit_to_datacite(object, doi)

        # Return the doi (old or new)
        Struct.new(:identifier).new(doi)
      end

      def mint_draft_doi
        client.create_draft_doi
      end

      private

      # Should the work be submitted for registration (or updating)?
      # @return [boolean]
      def register?(work)
        doi_enabled_work_type?(work) &&
          doi_minting_enabled? &&
          work.doi_status_when_public.in?(Hyrax::DOI::DataCiteRegistrar::STATES)
        # TODO: add more checks here to catch cases when updating is unnecessary
        # TODO: check that required metadata is present if set to registered or findable
      end

      # Check if work is DOI enabled
      def doi_enabled_work_type?(work)
        work.class.ancestors.include?(Hyrax::DOI::DOIBehavior) && work.class.ancestors.include?(Hyrax::DOI::DataCiteDOIBehavior)
      end

      def doi_minting_enabled?
        # TODO: Check feature flipper (needs to be per work type? per tenant for Hyku?)
        true
      end

      def public?(work)
        work.visibility == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      end

      def client
        @client ||= Hyrax::DOI::DataCiteClient.new(username: self.username, password: self.password, prefix: self.prefix, mode:)
      end

      # Do the heavy lifting of submitting the metadata, registering the url, and ensuring the correct status
      def submit_to_datacite(work, doi)
        # 1. Add metadata to the DOI (or update it)
        # TODO: check that required metadata is present if current DOI record is registered or findable OR handle error?
        client.put_metadata(doi, work_to_datacite_xml(work))

        # 2. Register a url with the DOI if it should be registered or findable
        client.register_url(doi, work_url(work)) if work.doi_status_when_public.in?(['registered', 'findable'])

        # 3. Always call delete metadata unless findable and public
        # Do this because it has no real effect on the metadata and
        # the put_metadata or register_url above may have made it findable.
        client.delete_metadata(doi) unless work.doi_status_when_public == 'findable' && public?(work)
      end

      # NOTE: default_url_options[:host] must be set for this method to work
      def work_url(work)
        Rails.application.routes.url_helpers.polymorphic_url(work)
      end

      # Replaced by Hyrax::DOI::DataCiteSerializer, which builds DataCite JSON for the
      # REST API directly. The bolognese XML crosswalk this used has been removed.
      def work_to_datacite_xml(_work)
        raise NotImplementedError, 'DataCite serialization is not implemented yet'
      end
    end
  end
end
