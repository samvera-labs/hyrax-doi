# frozen_string_literal: true
require 'bolognese'

module Bolognese
  module Writers
    # Use this with Bolognese like the following:
    # m = Bolognese::Metadata.new(input: '10.18130/v3-k4an-w022')
    # Then crosswalk it with:
    # m.hyrax_work
    module HyraxWorkWriter
      def hyrax_work
        attributes = {
          'doi' => build_hyrax_work_doi,
          'identifier' => identifiers,
          'title' => titles&.pluck("title"),
          # FIXME: This may not roundtrip since datacite normalizes the creator name
          'creator' => creators&.pluck("name"),
          'publisher' => Array(publisher),
          'description' => descriptions&.pluck("description")
        }
        hyrax_work_class = determine_hyrax_work_class
        # Only pass attributes that the work type knows about
        hyrax_work_class.new(attributes.slice(*hyrax_work_class.attribute_names))
      end

      private

      def determine_hyrax_work_class
        types["hyrax"]&.safe_constantize ||
          types["resource_type"]&.safe_constantize ||
          build_hyrax_work_class
      end

      def build_hyrax_work_class
        Class.new(ActiveFedora::Base).tap do |c|
          c.include ::Hyrax::WorkBehavior
          c.include ::Hyrax::BasicMetadata
        end
      end

      def build_hyrax_work_doi
        doi.sub('https://doi.org/', '')
      end
    end
  end
end
