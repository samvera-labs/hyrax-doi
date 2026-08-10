# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIBehavior
      extend ActiveSupport::Concern

      DOI_REGEX = %r{\A10\.\d{4,}(\.\d+)*/[-._;():/A-Za-z\d]+\z}

      # Declared on the class rather than contributed to a metadata profile because
      # Hyrax::Flexibility layers a profile schema onto the singleton, on top of the
      # class schema -- so a class-level attribute survives both flex modes.
      #
      # Validation lives on the form; Valkyrie resources have no ActiveModel validations.
      included do
        class_attribute :doi_attribute, instance_writer: false, default: :doi
        holds_doi_in :doi
      end

      class_methods do
        # Point the gem at an attribute other than `doi`. A repository may hold DOIs in
        # `identifier`, or in a field named for what it identifies rather than for the
        # scheme.
        #
        #   class Monograph < Hyrax::Work
        #     include Hyrax::DOI::DOIBehavior
        #     holds_doi_in :identifier
        #   end
        def holds_doi_in(name)
          self.doi_attribute = name.to_sym
          # Redeclaring raises Dry::Struct::RepeatedAttributeError, which would make the
          # gem unloadable in a repository that already has the field. The host's
          # declaration wins, including its type. Hyrax::Flexibility guards the same way.
          return if has_attribute?(doi_attribute)

          attribute doi_attribute, Valkyrie::Types::Array.of(Valkyrie::Types::String)
        end
      end

      # Reads through whichever attribute holds the DOI, so callers need not know its
      # name. Always an array: the host's own declaration wins on type, so the
      # underlying value may be a bare string.
      def doi_value
        Array.wrap(try(self.class.doi_attribute))
      end

      # Callers pass an array, since the PersistentIdentifier record is the source of truth
      # and a resource may hold several identifiers. Where the host declared the attribute
      # to hold one value and reject an array, write the first value rather than letting
      # the type error fail the sync.
      def doi_value=(value)
        writer = "#{self.class.doi_attribute}="
        public_send(writer, value)
      rescue Dry::Types::CoercionError
        public_send(writer, Array.wrap(value).first)
      end

      def persistent_identifiers
        return Hyrax::DOI::PersistentIdentifier.none if id.blank?

        Hyrax::DOI::PersistentIdentifier.for_resource(id)
      end

      def doi_record
        return nil if id.blank?

        Hyrax::DOI::PersistentIdentifier.primary_for(resource_id: id, scheme: 'doi')
      end

      # What the provider last reported, as distinct from doi_status_when_public, which
      # is the depositor's intent. The two legitimately differ: a work intended to be
      # findable stays registered while it is private.
      def doi_state
        doi_record&.state
      end

      # The PersistentIdentifier record is the source of truth. The work attribute is a
      # projection of it, kept so Solr indexing, the show page, and existing APIs keep
      # working; this refreshes that projection.
      def sync_doi_projection!
        self.doi_value = Array.wrap(doi_record&.value)
      end

      # Override to name the registrar this class mints with.
      def doi_registrar
        nil
      end

      # Override to pass options to the registrar.
      def doi_registrar_opts
        {}
      end
    end
  end
end
