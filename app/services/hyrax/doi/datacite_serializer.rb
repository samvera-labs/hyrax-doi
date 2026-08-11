# frozen_string_literal: true
module Hyrax
  module DOI
    class DataCiteSerializer
      # Required for a registered or findable DOI. Draft DOIs need none of it.
      REQUIRED = %w[creators titles publisher publicationYear resourceTypeGeneral].freeze

      # Where each DataCite field reads from when the profile declares nothing.
      DEFAULT_SOURCES = {
        'creators' => :creator,
        'titles' => :title,
        'publisher' => :publisher,
        'publicationYear' => :date_created,
        'resourceTypeGeneral' => :resource_type,
        'descriptions' => :description,
        'subjects' => :keyword
      }.freeze

      # The work fields feeding DataCite's required set, for a caller that needs to name
      # them before a save -- the deposit form warns about blanks. Resolved through the
      # profile mapping, so a repository that feeds publicationYear from something other
      # than date_created gets its own field named.
      def self.required_work_fields
        sources = DEFAULT_SOURCES.merge(profile_mapping)
        REQUIRED.filter_map { |field| sources[field] }.uniq
      end

      # `datacite_mapping` keys on m3 properties, inverted to DataCite field => work
      # field, so which field feeds which is profile data rather than code. Absent from
      # Hyrax's own profiles; adopters add it.
      def self.profile_mapping
        properties = Hyrax::FlexibleSchema.current_version&.dig('properties') || {}
        properties.each_with_object({}) do |(field, config), mapping|
          target = config.is_a?(Hash) && config['datacite_mapping']
          mapping[target.to_s] = field.to_sym if target.present?
        end
      rescue StandardError
        # A missing or unreadable profile is not a reason to fail a deposit.
        {}
      end

      def initialize(work, url: nil)
        @work = work
        @url = url
      end

      def to_attributes
        {
          titles:,
          creators:,
          publisher:,
          publicationYear: publication_year,
          types: { resourceTypeGeneral: resource_type_general }.compact_blank,
          descriptions:,
          subjects:,
          url:
        }.compact_blank
      end

      # Which required fields a work cannot supply, so a caller can say so before
      # DataCite rejects the submission.
      def missing_required
        REQUIRED.reject { |field| required_value_present?(field) }
      end

      private

      attr_reader :work, :url

      def titles
        values_for('titles').map { |title| { title: title.to_s } }
      end

      def creators
        extracted = extractor_for(:creator)&.call(work)
        return Array.wrap(extracted) if extracted.present?

        values_for('creators').map { |name| { name: name.to_s } }
      end

      def publisher
        extracted = extractor_for(:publisher)&.call(work)
        return extracted if extracted.present?

        name = values_for('publisher').first
        { name: name.to_s } if name.present?
      end

      # The source may be a full date or an EDTF string, so the year is extracted rather than
      # parsed. Nil when there is none: guessing a publication year would put a wrong date on
      # a permanent public record.
      def publication_year
        year = values_for('publicationYear').first.to_s[/\d{4}/]
        year&.to_i
      end

      def resource_type_general
        values_for('resourceTypeGeneral').first.presence
      end

      def descriptions
        values_for('descriptions').map { |text| { description: text.to_s, descriptionType: 'Abstract' } }
      end

      def subjects
        values_for('subjects').map { |term| { subject: term.to_s } }
      end

      def source_for(datacite_field)
        self.class.profile_mapping[datacite_field] || DEFAULT_SOURCES[datacite_field]
      end

      def values_for(datacite_field)
        source = source_for(datacite_field)
        return [] if source.blank?

        Array.wrap(work.try(source)).compact_blank
      end

      def extractor_for(field)
        Hyrax::DOI.config.public_send("#{field}_extractor")
      end

      # Reads what the payload will actually carry, not the raw field: an extractor may supply
      # creators or a publisher the work has no field for, and that counts as present.
      def required_value_present?(field)
        case field
        when 'creators' then creators.present?
        when 'publisher' then publisher.present?
        when 'publicationYear' then publication_year.present?
        when 'resourceTypeGeneral' then resource_type_general.present?
        else values_for(field).any?
        end
      end
    end
  end
end
