# frozen_string_literal: true
require 'bolognese'

module Bolognese
  module Readers
    # Use this with Bolognese like the following:
    # m = Bolognese::Metadata.new(input: work.attributes.merge(has_model: work.has_model).to_json, from: 'hyrax_work')
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

        # TODO: Map work.resource_type or work.
        resource_type_general = "Other"
        resource_type = meta.fetch('resource_type', nil).presence || meta.fetch('has_model', nil) || "Work"
        # schema_org = Bolognese::Utils::CR_TO_SO_TRANSLATIONS[resource_type.to_s.underscore.camelcase] || Bolognese::Utils::DC_TO_SO_TRANSLATIONS[resource_type_general.to_s.dasherize] || "CreativeWork"
        types = {
          "resourceTypeGeneral" => resource_type_general,
          "resourceType" => resource_type
          # "schemaOrg" => schema_org,
          # "citeproc" => Bolognese::Utils::CR_TO_CP_TRANSLATIONS[resource_type.to_s.underscore.camelcase] || Bolognese::Utils::SO_TO_CP_TRANSLATIONS[schema_org] || "article",
          # "bibtex" => Bolognese::Utils::CR_TO_BIB_TRANSLATIONS[resource_type.to_s.underscore.camelcase] || Bolognese::Utils::SO_TO_BIB_TRANSLATIONS[schema_org] || "misc",
          # "ris" => Bolognese::Utils::CR_TO_RIS_TRANSLATIONS[resource_type.to_s.underscore.camelcase] || Bolognese::Utils::DC_TO_RIS_TRANSLATIONS[resource_type_general.to_s.dasherize] || "GEN"
        }.compact

        creators = if meta.fetch("creator", nil).present?
          get_authors(Array.wrap(meta.fetch("creator", nil)))
        end

        titles = Array.wrap(meta.dig("title")).map do |r|
          if r.blank?
            nil
          elsif r.is_a?(String)
            { "title" => sanitize(r) }
          end
        end.compact

        descriptions = Array.wrap(meta.dig("description")).map do |r|
          if r.blank?
            nil
          elsif r.is_a?(String)
            { "description" => sanitize(r) }
          end
        end.compact

        # FIXME: pull this from the work's metadata
        publication_year = Time.zone.today.year

        { 
          # "id" => meta.fetch('id', nil),
          "identifiers" => parse_attributes(meta.fetch('identifier', nil)).to_s.strip.presence,
          "types" => types,
          "doi" => normalize_doi(meta.fetch('doi', nil)),
          #"url" => normalize_id(meta.fetch("URL", nil)),
          "titles" => titles,
          "creators" => creators,
          #"contributors" => contributors,
          #"container" => container,
          "publisher" => parse_attributes(meta.fetch("publisher", nil)).to_s.strip.presence,
          #"related_identifiers" => related_identifiers,
          #"dates" => dates,
          "publication_year" => publication_year,
          "descriptions" => descriptions,
          # "rights_list" => rights_list,
          # "version_info" => meta.fetch("version", nil),
          # "subjects" => subjects
          #"state" => state
        }.merge(read_options)
      end
    end
  end
end