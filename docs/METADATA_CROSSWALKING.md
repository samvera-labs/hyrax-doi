# METADATA CROSSWALKING WITH BOLOGNESE
# Summary
How does your Hyrax application's metadata connect to the metadata from your DOI source?  It does so with your help.  Customize how metadata from [DOI Registration Agent](https://www.doi.org/registration_agencies.html) is mapped to application's metadata by adding a custom reader and writer to your Hyrax application.

## Implementation
Developer should be between adding the DOI RA credentials and adding the DOI field to the single work show page.  


## Custom Reader
This is a sample reader and will need to change based on what metadata is in use for your particular instance of Hyrax.
`file path: app/services/bolognese/readers/hyrax_work_reader.rb` 

```
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
          "identifiers" => read_hyrax_work_identifiers(meta),
          "types" => read_hyrax_work_types(meta),
          "doi" => normalize_doi(meta.fetch('doi', nil)&.first),
          # "url" => normalize_id(meta.fetch("URL", nil)),
          "titles" => read_hyrax_work_titles(meta),
          "creators" => read_hyrax_work_creators(meta),
          "contributors" => read_hyrax_work_contributors(meta),
          # "container" => container,
          "publisher" => read_hyrax_work_publisher(meta),
          # "related_identifiers" => related_identifiers,
          # "dates" => dates,
          "publication_year" => read_hyrax_work_publication_year(meta),
          "descriptions" => read_hyrax_work_descriptions(meta),
          # "rights_list" => rights_list,
          # "version_info" => meta.fetch("version", nil),
          "subjects" => read_hyrax_work_subjects(meta)
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

      def read_hyrax_work_contributors(meta)
        get_authors(Array.wrap(meta.fetch("contributor", nil))) if meta.fetch("contributor", nil).present?
      end

      def read_hyrax_work_titles(meta)
        Array.wrap(meta.fetch("title", nil)).select(&:present?).collect { |r| { "title" => sanitize(r) } }
      end

      def read_hyrax_work_descriptions(meta)
        Array.wrap(meta.fetch("description", nil)).select(&:present?).collect { |r| { "description" => sanitize(r) } }
      end

      def read_hyrax_work_publication_year(meta)
        date = meta.fetch("date_created", nil)&.first
        date ||= meta.fetch("date_uploaded", nil)
        Date.edtf(date.to_s).year
      rescue StandardError
        Time.zone.today.year
      end

      def read_hyrax_work_subjects(meta)
        Array.wrap(meta.fetch("keyword", nil)).select(&:present?).collect { |r| { "subject" => sanitize(r) } }
      end

      def read_hyrax_work_identifiers(meta)
        Array.wrap(meta.fetch("identifier", nil)).select(&:present?).collect { |r| { "identifier" => sanitize(r) } }
      end

      def read_hyrax_work_publisher(meta)
        # Fallback to ':unav' since this is a required field for datacite
        # TODO: Should this default to application_name?
        parse_attributes(meta.fetch("publisher")).to_s.strip.presence || ":unav"
      end
    end
  end
end
```


## Custom Writer
This is a sample writer and will need to change based on what metadata is in use for your particular instance of Hyrax.
`file path: app/services/bolognese/writers/hyrax_work_reader.rb`

```
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
          'publisher' => Array(publisher),
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
        Class.new(ActiveFedora::Base).tap do |c|
          c.include ::Hyrax::WorkBehavior
          c.include ::Hyrax::DOI::DOIBehavior
          # Put BasicMetadata include last since it finalizes the metadata schema
          c.include ::Hyrax::BasicMetadata
        end
      end

      def build_hyrax_work_doi
        Array(doi&.sub('https://doi.org/', ''))
      end

      def build_hyrax_work_description
        return nil if descriptions.blank?
        descriptions.pluck("description").map { |d| Array(d).join("\n") }
      end
    end
  end
end
```