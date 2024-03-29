# frozen_string_literal: true
module Hyrax
  module DOI
    class DataCiteClient
      attr_reader :username, :password, :prefix, :mode

      TEST_BASE_URL = "https://api.test.datacite.org/"
      TEST_MDS_BASE_URL = "https://mds.test.datacite.org/"
      PRODUCTION_BASE_URL = "https://api.datacite.org/"
      PRODUCTION_MDS_BASE_URL = "https://mds.datacite.org/"

      def initialize(username:, password:, prefix:, mode: :production)
        @username = username
        @password = password
        @prefix = prefix
        @mode = mode
      end

      # Mint a draft DOI without metadata or a url
      # If you already have a DOI and want to register it as a draft then go through the normal process (put_metadata/register_url)
      def create_draft_doi
        # Use regular api instead of mds for metadata-less url-less draft doi creation
        response = connection.post('dois', draft_doi_payload.to_json, "Content-Type" => "application/vnd.api+json")
        raise Error.new('Failed creating draft DOI', response) unless response.status == 201

        JSON.parse(response.body)['data']['id']
      end

      def delete_draft_doi(doi)
        response = mds_connection.delete("doi/#{doi}")
        raise Error.new('Failed deleting draft DOI', response) unless response.status == 200

        doi
      end

      def get_metadata(doi)
        response = mds_connection.get("metadata/#{doi}")
        raise Error.new('Failed getting DOI metadata', response) unless response.status == 200

        Nokogiri::XML(response.body).remove_namespaces!
      end

      # This will mint a new draft DOI if the passed doi parameter is blank
      # The passed datacite xml needs an identifier (just the prefix when minting new DOIs)
      # Beware: This will convert registered DOIs into findable!
      def put_metadata(doi, metadata)
        doi = prefix if doi.blank?
        response = mds_connection.put("metadata/#{doi}", metadata, { 'Content-Type': 'application/xml;charset=UTF-8' })
        raise Error.new('Failed creating metadata for DOI', response) unless response.status == 201

        /^OK \((?<found_or_created_doi>.*)\)$/ =~ response.body
        found_or_created_doi
      end

      # Beware: This will make findable DOIs become registered (by setting is_active to false)
      # Otherwise this has no effect on the DOI's metadata (even when draft)
      # Beware: Attempts to delete the metadata of an unknown DOI will actually create a blank draft DOI
      def delete_metadata(doi)
        response = mds_connection.delete("metadata/#{doi}")
        raise Error.new('Failed deleting DOI metadata', response) unless response.status == 200

        doi
      end

      def get_url(doi)
        response = mds_connection.get("doi/#{doi}")
        raise Error.new('Failed getting DOI url', response) unless response.status == 200

        response.body
      end

      # Beware: This will convert draft DOIs to findable!
      # Metadata needs to be registered for a DOI before a url can be registered
      def register_url(doi, url)
        payload = "doi=#{doi}\nurl=#{url}"
        response = mds_connection.put("doi/#{doi}", payload, { 'Content-Type': 'text/plain;charset=UTF-8' })
        raise Error.new('Failed registering url for DOI', response) unless response.status == 201

        url
      end

      class Error < RuntimeError
        ##
        # @!attribute [r] status
        #   @return [Integer]
        attr_reader :status

        ##
        # @param msg      [String]
        # @param response [Faraday::Response]
        def initialize(msg = '', response = nil)
          if response
            @status = response.status
            msg += "\n#{@status}: #{response.reason_phrase}\n"
            msg += response.body
          end

          super(msg)
        end
      end

      private

      def connection
        Faraday.new(url: base_url) do |c|
          c.basic_auth(username, password)
          c.adapter(Faraday.default_adapter)
        end
      end

      def mds_connection
        Faraday.new(url: mds_base_url) do |c|
          c.basic_auth(username, password)
          c.adapter(Faraday.default_adapter)
        end
      end

      def draft_doi_payload
        {
          "data": {
            "type": "dois",
            "attributes": {
              "prefix": prefix
            }
          }
        }
      end

      # Ensre that `mode` is not a string
      def base_url
        mode&.to_sym == :production ? PRODUCTION_BASE_URL : TEST_BASE_URL
      end

      def mds_base_url
        mode&.to_sym == :production ? PRODUCTION_MDS_BASE_URL : TEST_MDS_BASE_URL
      end
    end
  end
end
