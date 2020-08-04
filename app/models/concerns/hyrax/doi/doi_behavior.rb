# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIBehavior
      extend ActiveSupport::Concern

      included do
        # TODO: Need to make this multiple in order to handle versioning
        property :doi, predicate: ::RDF::Vocab::BIBO.doi, multiple: false do |index|
          index.as :stored_sortable
        end
        property :doi_status_when_public, predicate: ::RDF::URI('http://samvera.org/ns/hyrax/doi#doi_status_when_public'), multiple: false do |index|
          index.as :stored_sortable
        end

        # TODO: Add a more helpful error message
        validates :doi, format: { with: /\A10\.\d{4,}(\.\d+)*\/[-._;():\/A-Za-z\d]+\z/ }, allow_nil: true
        # TODO: turn controlled vocab here into a frozen constant to allow for extensions and reuse
        validates :doi_status_when_public, inclusion: { in: [:draft, :registered, :findable] }, allow_nil: true

        around_save :register_doi, if: Proc.new{ |w| registrar.try(:register?, object: self) }

        # Override setter to allow passing arrays since Hyrax::Identifier::Dispatcher does it
        # Maybe Hyrax should introspect and send singular vs. multiple based upon property definition
        alias_method :_doi=, :doi=
        def doi=(value)
          self._doi = Array(value).first
        end
      end

      private

      def register_doi
        yield
        Hyrax::DOI::RegisterDOIJob.perform_later(self, registrar: registrar_name.to_s, registrar_opts: registrar_opts)
      end

      # Can be overridden
      def registrar
        return nil unless registrar_name
        @registrar ||= Hyrax::Identifier::Registrar.for(registrar_name, **registrar_opts)
      end

      # Can be overridden
      def registrar_name
        @registrar_name ||= Hyrax.config.identifier_registrars&.keys&.first
      end

      # Can be overridden
      # Builder passed in here?  Builder includes mapping from work type attributes to DOI metadata
      # Need to pass configuration here (e.g. credentials, prefix, etc.)
      def registrar_opts
        @registrar_opts ||= {}
      end
    end
  end
end
