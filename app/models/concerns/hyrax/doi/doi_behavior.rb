# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIBehavior
      extend ActiveSupport::Concern

      included do
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
      end
    end
  end
end
