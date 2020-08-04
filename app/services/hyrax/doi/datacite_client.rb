module Hyrax
  module DOI
    class DataciteClient
      attr_reader :base_url, :username, :password, :prefix, :mode

      TEST_BASE_URL = "https://api.test.datacite.org/"
      TEST_MDS_BASE_URL = "https://mds.test.datacite.org/"
      PRODUCTION_BASE_URL = "https://api.datacite.org"
      PRODUCTION_MDS_BASE_URL = "https://mds.datacite.org/"

      def initialize(username:, password:, prefix:, mode: :production)
        @username = username
        @password = password
        @prefix = prefix
        @mode = mode
      end

      def mint_draft_doi
        # Use regular api instead of mds for metadata-less url-less draft doi creation
        resp = connection.post('dois', draft_doi_payload.to_json, "Content-Type" => "application/json")
        raise Error.new('', response) unless response.status == 201

        doc = Nokogiri::XML(resp.body)
        doc.xpath('//xmlns:identifier', doc.namespaces).text
      end

      def delete_draft_doi(doi)
        resp = mds_connection.delete("doi/#{doi}")
        raise Error.new('', response) unless response.status == 200

        doi
      end

      def get_metadata(doi)
        resp = mds_connection.get("metadata/#{doi}")
        raise Error.new('', response) unless response.status == 200

        Nokogiri::XML(response.body)
      end

      def put_metadata(doi, metadata)
        resp = mds_connection.put("metadata/#{doi}", metadata)
        raise Error.new('', response) unless response.status == 200

        # Does this return a new metadata from the response body
        metadata
      end

      def register(doi, url)
        payload = "doi=#{doi}\nurl=#{url}"
        resp = mds_connection.put("doi/#{doi}", payload)
        raise Error.new('', response) unless response.status == 201

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
            msg += "#{@status}: #{response.reason_phrase}\n\n"
            msg += response.body
          end

          super(msg)
        end
      end

      private

      def connection
        Faraday.new(url: base_url) do |c| 
          c.basic_auth(dc.username, dc.password)
          c.adapter(Faraday.default_adapter)
        end
      end

      def mds_connection
        Faraday.new(url: base_mds_url) do |c| 
          c.basic_auth(dc.username, dc.password)
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

      def base_url
        mode == :production ? PRODUCTION_BASE_URL : TEST_BASE_URL
      end

      def mds_base_url
        mode == :production ? PRODUCTION_MDS_BASE_URL : TEST_MDS_BASE_URL
      end
    end
  end
end
