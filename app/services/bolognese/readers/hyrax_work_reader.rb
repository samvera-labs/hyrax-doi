# frozen_string_literal: true
require 'bolognese'

module Bolognese
  module Readers
    # Use this with Bolognese like the following:
    # m = Bolognese::Metadata.new(input: work.attributes.merge(has_model: work.has_model.first).to_json, from: 'hyrax_work')
    # Then crosswalk it with:
    # m.datacite
    # Or:
    # m.ris
    module HyraxWorkReader
      # Not usable right now given how Metadata#initialize works
      # def get_hyrax_work(id: nil, **options)
      #   work = ActiveFedora::Base.find(id)
      #   { "string" => work.attributes.merge(has_model: work.has_model).to_json }
      # end

      def read_hyrax_work(string: nil, **options)
        read_options = ActiveSupport::HashWithIndifferentAccess.new(options.except(:doi, :id, :url, :sandbox, :validate, :ra))

        meta = string.present? ? Maremma.from_json(string) : {}

        {
          # "id" => meta.fetch('id', nil),
          "identifiers" => parse_attributes(meta.fetch('identifier', nil)).to_s.strip.presence,
          "types" => read_hyrax_work_types(meta),
          "doi" => normalize_doi(meta.fetch('doi', nil)&.first),
          # "url" => normalize_id(meta.fetch("URL", nil)),
          "titles" => read_hyrax_work_titles(meta),
          "creators" => read_hyrax_work_creators(meta),
          # "contributors" => contributors,
          # "container" => container,
          "publisher" => parse_attributes(meta.fetch("publisher", nil)).to_s.strip.presence,
          # "related_identifiers" => related_identifiers,
          # "dates" => dates,
          "publication_year" => read_hyrax_work_publication_year(meta),
          "descriptions" => read_hyrax_work_descriptions(meta)
          # "rights_list" => rights_list,
          # "version_info" => meta.fetch("version", nil),
          # "subjects" => subjects
          # "state" => state
        }.merge(read_options)
      end

      private

      def read_hyrax_work_types(meta)
        # TODO: Map work.resource_type or work.
        resource_type_general = "Other"
        hyrax_resource_type = meta.fetch('has_model', nil) || "Work"
        resource_type = meta.fetch('resource_type', nil).presence || hyrax_resource_type
        {
          "resourceTypeGeneral" => resource_type_general,
          "resourceType" => resource_type,
          "hyrax" => hyrax_resource_type
        }.compact
      end

      def read_hyrax_work_creators(meta)
        get_authors(Array.wrap(meta.fetch("creator", nil))) if meta.fetch("creator", nil).present?
      end

      def read_hyrax_work_titles(meta)
        Array.wrap(meta.dig("title")).map do |r|
          if r.blank?
            nil
          elsif r.is_a?(String)
            { "title" => sanitize(r) }
          end
        end.compact
      end

      def read_hyrax_work_descriptions(meta)
        Array.wrap(meta.dig("description")).map do |r|
          if r.blank?
            nil
          elsif r.is_a?(String)
            { "description" => sanitize(r) }
          end
        end.compact
      end

      def read_hyrax_work_publication_year(_meta)
        # FIXME: pull this from the work's metadata
        Time.zone.today.year
      end
    end
  end
end
