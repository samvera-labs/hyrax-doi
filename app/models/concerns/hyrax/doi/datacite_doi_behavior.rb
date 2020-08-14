# frozen_string_literal: true
module Hyrax
  module DOI
    module DataCiteDOIBehavior
      extend ActiveSupport::Concern

      included do
        property :doi_status_when_public, predicate: ::RDF::URI('http://samvera.org/ns/hyrax/doi#doi_status_when_public'), multiple: false do |index|
          index.as :stored_sortable
        end

        validates :doi_status_when_public, inclusion: { in: Hyrax::DOI::DataCiteRegistrar::STATES }, allow_nil: true
      end

      # Override
      def doi_registrar
        'datacite'
      end
    end
  end
end
