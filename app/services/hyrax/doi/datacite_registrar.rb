module Hyrax
  module DOI
    class DataciteRegistrar < Hyrax::Identifier::Registrar
      class_attribute :prefix, :username, :password, :mode

      def initialize(builder: Hyrax::Identifier::Builder.new(prefix: self.prefix))
        super
      end

      ##
      # @param object [#id]
      #
      # @return [#identifier]
      # @raise [NotImplementedError] when the method is abstract
      def register!(object: work)
        if mint_draft?
          Struct.new(:identifier).new(client.mint_draft_doi)
        elsif mint?
          # create metadata then register doi url
          # Use bolognese to crosswalk to datacite xml
          metadata = Bolognese::Metadata.new(input: object.attributes.merge(has_model: object.has_model.first).to_json, from: 'hyrax_work').datacite
          new_doi = client.put_metadata(object.doi || prefix, metadata)
          # FIXME: set host in a better way
          url = Rails.application.routes.url_helpers.polymorphic_url(object, host: 'http://example.com')
          client.register(new_doi, url)
          Struct.new(:identifier).new(new_doi)
        end 
      end

      # Should the work be submitted for registration (or updating)?
      # @return [boolean]
      def register?(object: work)
        doi_enabled_work_type?(object) &&
        doi_minting_enabled? &&
        (doi_requested?(object) ||
         doi_status_change?(object) ||
         doi_metadata_changed?(object) ||
         public_visibility_changed?(object))
      end

      private

      def client
        @client ||= Hyrax::DOI::DataciteClient.new(username: self.username, password: self.password, prefix: self.prefix, mode: mode)
      end

      # Check if work is DOI enabled
      def doi_enabled_work_type?(work)
        work.class.ancestors.include? Hyrax::DOI::DOIBehavior
      end

      def doi_minting_enabled?
        # Check feature flipper (needs to be per tenant per work type?)
        return true
      end

      # Check if DOI is wanted eventually and one doesn't already exist
      def doi_requested?(work)
        # TODO: Need to handle the case when work.new_record? is true but doi is set
        work.doi.blank? && work.doi_status_when_public.in?([:draft, :registered, :findable])
      end

      # Check if doi_status_when_public changes to another possible status
      def doi_status_change?(work)
        work.doi.present? && work.doi_status_when_public_changed? &&
          (work.doi_status_when_public_changed?(from: nil, to: :draft) ||
           work.doi_status_when_public_changed?(from: nil, to: :registered) ||
           work.doi_status_when_public_changed?(from: nil, to: :findable) ||
           work.doi_status_when_public_changed?(from: :draft, to: nil) ||
           work.doi_status_when_public_changed?(from: :draft, to: :registered) ||
           work.doi_status_when_public_changed?(from: :draft, to: :findable) ||
           work.doi_status_when_public_changed?(from: :registered, to: :findable) ||
           work.doi_status_when_public_changed?(from: :findable, to: :registered))
      end

      # Check if metadata sent to the registrar has changed
      def doi_metadata_changed?(work)
        # TODO: When registar rmetadata changes
        # Need to know registrar to do this?
        # if work.changes.keys.any? { |k| k.in?(registrar::METADATA_FIELDS)}
        return false
      end

      # Check if the work becomes public or ceases being public
      def public_visibility_changed?(work)
        # TODO: When work becomes public or ceases to be public
        # The code below doesn't work because visibility_changed?(to:/from:) doesn't work because visibility isn't setup with ActiveModel::Dirty
        if (work.visibility_changed?(to: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ) ||
           work.visibility_changed?(from: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ))
          return true
        end

        return false
      end

      def mint_draft?
        return false
      end

      def mint?
        return false
      end
    end
  end
end