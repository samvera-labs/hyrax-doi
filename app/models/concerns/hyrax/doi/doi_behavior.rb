# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIBehavior
      extend ActiveSupport::Concern

      DOI_REGEX = /\A10\.\d{4,}(\.\d+)*\/[-._;():\/A-Za-z\d]+\z/

      included do
        property :doi, predicate: ::RDF::Vocab::BIBO.doi, multiple: true do |index|
          index.as :stored_sortable
        end
        property :doi_status_when_public, predicate: ::RDF::URI('http://samvera.org/ns/hyrax/doi#doi_status_when_public'), multiple: false do |index|
          index.as :stored_sortable
        end

        validate :validate_doi
        # TODO: turn controlled vocab here into a frozen constant to allow for extensions and reuse
        validates :doi_status_when_public, inclusion: { in: [:draft, :registered, :findable] }, allow_nil: true
      end

      private

      def validate_doi
        Array(doi).each do |doi|
          errors.add(:doi, "DOI (#{doi}) is invalid.") unless doi.match? DOI_REGEX
        end
      end
    end
  end
end
