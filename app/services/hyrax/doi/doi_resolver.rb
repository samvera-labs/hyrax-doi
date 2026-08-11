# frozen_string_literal: true
require 'faraday/follow_redirects'

module Hyrax
  module DOI
    # Reads descriptive metadata for a DOI minted by anyone, so a depositor can fill a
    # deposit form from an existing record.
    class DOIResolver
      RESOLVER = 'https://doi.org'

      # CSL JSON rather than DataCite's own media type: doi.org serves it for every
      # registration agency, while application/vnd.datacite.datacite+json 406s on a
      # CrossRef DOI -- and a published-article DOI is the common thing to paste.
      MEDIA_TYPE = 'application/vnd.citationstyles.csl+json'

      # Where each work field reads from. Agencies differ: DataCite puts keywords in
      # `categories`, CrossRef in `subject`, so several sources per field is normal.
      SOURCES = {
        title: %w[title],
        description: %w[abstract],
        publisher: %w[publisher],
        keyword: %w[categories subject]
      }.freeze

      def initialize(connection: nil)
        @connection = connection
      end

      # @param doi [String]
      # @return [Hash{Symbol => Array}] work attributes, each multivalued as Hyrax expects
      # @raise [Hyrax::DOI::NotFoundError] the DOI does not resolve, or resolves to
      #   something that is not CSL JSON
      # @raise [Hyrax::DOI::Error] doi.org could not be reached
      def attributes_for(doi)
        to_attributes(fetch(doi))
      end

      private

      def fetch(doi)
        response = connection.get(doi.to_s) do |request|
          request.headers['Accept'] = MEDIA_TYPE
        end

        raise Hyrax::DOI::NotFoundError, "No metadata found for #{doi}" if response.status == 404
        raise Hyrax::DOI::Error, "doi.org returned #{response.status}" unless response.success?

        parse(response.body, doi)
      end

      # doi.org answers 200 with an HTML landing page when it cannot honor the requested
      # media type, so a successful status is not by itself CSL JSON. Valid JSON is not
      # either: an array or a bare string parses cleanly and is still not a CSL record.
      def parse(body, doi)
        parsed = JSON.parse(body.to_s)
        raise Hyrax::DOI::NotFoundError, "No CSL metadata found for #{doi}" unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        raise Hyrax::DOI::NotFoundError, "No CSL metadata found for #{doi}"
      end

      def to_attributes(csl)
        attributes = SOURCES.each_with_object({}) do |(field, keys), result|
          value = keys.filter_map { |key| csl[key].presence }.first
          result[field] = Array.wrap(value) if value.present?
        end

        creators = creators_from(csl)
        attributes[:creator] = creators if creators.present?
        date = date_from(csl)
        attributes[:date_created] = [date] if date.present?
        attributes
      end

      # Family-first, matching how Hyrax's name authorities and DataCite both expect a
      # personal name. A CSL author may instead carry `literal` for an organization.
      def creators_from(csl)
        Array.wrap(csl['author']).filter_map do |author|
          next author['literal'].presence if author['literal'].present?

          [author['family'].presence, author['given'].presence].compact.join(', ').presence
        end
      end

      # `issued` is the only date field both agencies populate consistently. CrossRef also
      # sends published/published-print/published-online, which disagree with each other.
      #
      # date-parts is [[year, month, day]] with month and day optional, so the precision
      # available is preserved rather than padded into a false full date.
      def date_from(csl)
        parts = csl.dig('issued', 'date-parts')&.first
        return nil if parts.blank?

        year, month, day = Array.wrap(parts).map { |part| Integer(part, exception: false) }
        return nil if year.blank?

        [format('%04d', year), month && format('%02d', month), day && format('%02d', day)]
          .compact.join('-')
      end

      def connection
        @connection ||= Faraday.new(url: RESOLVER) do |faraday|
          # doi.org redirects to the registration agency's own content-negotiation host.
          faraday.response :follow_redirects
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
