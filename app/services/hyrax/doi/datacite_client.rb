# frozen_string_literal: true
module Hyrax
  module DOI
    class DataCiteClient
      attr_reader :username, :password, :prefix, :mode

      TEST_BASE_URL = 'https://api.test.datacite.org/'
      PRODUCTION_BASE_URL = 'https://api.datacite.org/'

      JSON_API_TYPE = 'application/vnd.api+json'

      # DataCite moves a DOI between states by an explicit `event` rather than by side
      # effects of metadata operations. Omitting it leaves the state alone, so a new DOI
      # stays draft -- the only state a DOI can be deleted from.
      EVENTS = { register: 'register', publish: 'publish', hide: 'hide' }.freeze

      Record = Data.define(:doi, :state, :attributes)

      def initialize(username:, password:, prefix:, mode: :production)
        @username = username
        @password = password
        @prefix = prefix
        @mode = mode
      end

      # Is DataCite reachable? The heartbeat endpoint answers regardless of who is
      # asking, so this says nothing about whether the credentials work.
      def heartbeat
        response = connection.get('heartbeat')
        if response.status == 200
          PingResult.new(success: true, message: 'DataCite is reachable.')
        else
          PingResult.new(success: false, message: "DataCite returned #{response.status}.")
        end
      rescue Faraday::Error => e
        PingResult.new(success: false, message: "Could not reach DataCite: #{e.message}")
      end

      # Do these credentials work? Lists a single DOI, the cheapest authenticated read
      # available: it mints nothing and consumes no quota.
      def verify_credentials
        response = connection.get('dois', 'page[size]' => 1)
        case response.status
        when 200 then PingResult.new(success: true, message: 'DataCite accepted these credentials.')
        when 401, 403 then PingResult.new(success: false, message: 'DataCite rejected these credentials.')
        else PingResult.new(success: false, message: "DataCite returned #{response.status}.")
        end
      rescue Faraday::Error => e
        PingResult.new(success: false, message: "Could not reach DataCite: #{e.message}")
      end

      # Reserves a DOI with no metadata and no url. Sending only the prefix lets DataCite
      # assign the suffix.
      def create_draft_doi
        response = post('dois', data: { type: 'dois', attributes: { prefix: } })
        raise Error.new('Failed creating draft DOI', response) unless response.status == 201

        parse(response).doi
      end

      # Creates or updates a DOI in one idempotent call.
      def put_doi(doi, attributes:, event: nil)
        payload = attributes.dup
        payload[:event] = event if event.present?

        response = put("dois/#{doi}", data: { type: 'dois', attributes: payload })
        raise Error.new("Failed submitting DOI #{doi}", response) unless response.status.in?([200, 201])

        parse(response)
      end

      # @return [Record, nil] nil when DataCite has no such DOI
      def get_doi(doi)
        response = connection.get("dois/#{doi}")
        return nil if response.status == 404
        raise Error.new("Failed fetching DOI #{doi}", response) unless response.status == 200

        parse(response)
      end

      # Only drafts can be deleted; registered and findable DOIs are permanent.
      def delete_doi(doi)
        response = connection.delete("dois/#{doi}")
        raise Error.new("Failed deleting DOI #{doi}", response) unless response.status.in?([200, 204])

        true
      end

      class Error < RuntimeError
        attr_reader :status, :errors

        def initialize(msg = '', response = nil)
          if response
            @status = response.status
            @errors = extract_errors(response)
            msg += " -- #{@status}"
            msg += ": #{@errors.join('; ')}" if @errors.any?
          end

          super(msg)
        end

        private

        # JSON:API returns errors as [{source:, title:}, ...]. Keeping source and title
        # together is what makes the message name the offending field.
        def extract_errors(response)
          body = JSON.parse(response.body.presence || '{}')
          Array(body['errors']).map do |error|
            [error['source'], error['title'] || error['detail']].compact.join(' ')
          end
        rescue JSON::ParserError
          []
        end
      end

      private

      def post(path, body)
        connection.post(path, body.to_json)
      end

      def put(path, body)
        connection.put(path, body.to_json)
      end

      def parse(response)
        data = JSON.parse(response.body.presence || '{}')['data'] || {}
        attributes = data['attributes'] || {}
        Record.new(doi: data['id'], state: attributes['state'], attributes:)
      end

      # Memoized: a new connection per call rebuilds the middleware stack and forfeits
      # keep-alive, and a work update can make several requests.
      def connection
        @connection ||= Faraday.new(url: base_url, headers: { 'Content-Type' => JSON_API_TYPE }) do |c|
          c.request(:authorization, :basic, username, password)
          c.adapter(Faraday.default_adapter)
        end
      end

      def base_url
        mode&.to_sym == :production ? PRODUCTION_BASE_URL : TEST_BASE_URL
      end
    end
  end
end
