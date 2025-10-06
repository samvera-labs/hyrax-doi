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
          'identifier' => Array(identifiers).select { |id| id["identifierType"] != "DOI" }.pluck("identifier"),
          'doi' => build_hyrax_work_doi,
          'title' => titles&.pluck("title"),
          # FIXME: This may not roundtrip since datacite normalizes the creator name
          'creator' => creators&.pluck("name"),
          'contributor' => contributors&.pluck("name"),
          'publisher' => build_hyrax_work_publisher,
          'date_created' => Array(publication_year),
          'description' => build_hyrax_work_description,
          'keyword' => subjects&.pluck("subject")
        }
        hyrax_work_class = determine_hyrax_work_class
        # Only pass attributes that the work type knows about
        hyrax_work_class.new(attributes.slice(*hyrax_work_class.attribute_names))
      end

      private

      def determine_hyrax_work_class
        # Need to check that the class `responds_to? :doi`?
        types["hyrax"]&.safe_constantize || build_hyrax_work_class
      end

      def build_hyrax_work_class
        @hyrax_work_class ||= begin
          klass = Class.new(ActiveFedora::Base) do
            def self.name
              "Bolognese::Writers::DynamicHyraxWork"
            end

            def self.to_s
              name
            end
          end
          klass.include ::Hyrax::WorkBehavior
          klass.include ::Hyrax::DOI::DOIBehavior
          # Put BasicMetadata include last since it finalizes the metadata schema
          klass.include ::Hyrax::BasicMetadata
          klass
        end
      end

      def build_hyrax_work_doi
        Array(doi&.sub('https://doi.org/', ''))
      end

      def build_hyrax_work_description
        return nil if descriptions.blank?
        descriptions.pluck("description").map { |d| Array(d).join("\n") }
      end

      def build_hyrax_work_publisher
        return [] if publisher.blank?
        # For crossref data, publisher can be a hash like {"name" => "eLife Sciences Publications, Ltd"}
        # For datacite data, publisher is usually a string
        case publisher
        when Hash
          # Extract the actual publisher name
          Array(publisher['name'])
        when String
          [publisher]
        else
          Array(publisher)
        end
      end
    end
  end
end
