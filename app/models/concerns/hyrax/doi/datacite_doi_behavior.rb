# frozen_string_literal: true
module Hyrax
  module DOI
    module DataCiteDOIBehavior
      extend ActiveSupport::Concern

      included do
        property :doi_status_when_public, predicate: ::RDF::URI('http://samvera.org/ns/hyrax/doi#doi_status_when_public'), multiple: false do |index|
          index.as :stored_sortable
        end

        # TODO: turn controlled vocab here into a frozen constant to allow for extensions and reuse
        validates :doi_status_when_public, inclusion: { in: [:draft, :registered, :findable] }, allow_nil: true
      end

      # Override
      def doi_registrar
        :datacite
      end
    end
  end
end
