# frozen_string_literal: true
module Hyrax
  module DOI
    class DataCiteRegistrar < Hyrax::Identifier::Registrar
      STATES = %w[draft registered findable].freeze

      # DataCite state transitions are one-way past draft: a registered or findable DOI is
      # a public promise that the identifier resolves, so it can be hidden but never
      # withdrawn or demoted. Given what DataCite currently reports for a work, these are
      # the intents a depositor can no longer choose.
      def self.state_unreachable?(state, from:)
        return false if from.blank?

        case state.presence
        when nil then true
        when 'draft' then from != 'draft'
        else false
        end
      end

      attr_reader :credentials

      # Credentials are per instance, never class-level: a Sidekiq process runs threads
      # for several tenants at once, and process-wide state would let them overwrite each
      # other mid-flight.
      def initialize(builder: nil, credentials: nil)
        @credentials = credentials || Hyrax::DOI.credentials_for('datacite')
        super(builder: builder || Hyrax::Identifier::Builder.new(prefix: @credentials.prefix))
      end

      # Checks reachability first so an outage and a bad password produce different
      # messages: an operator can act on the difference.
      def ping
        return PingResult.new(success: false, message: 'DataCite credentials are incomplete.') unless credentials.complete?

        reachable = client.heartbeat
        return reachable if reachable.failure?

        client.verify_credentials
      end

      ##
      # @return [Hyrax::DOI::RegistrationResult]
      def register!(object: work)
        doi = Array(object.try(:doi_value) || object.try(:doi)).first
        return RegistrationResult.new(identifier: doi) unless register?(object)

        serializer = DataCiteSerializer.new(object, url: work_url(object))
        missing = serializer.missing_required if requires_metadata?(object)
        if missing.present?
          return RegistrationResult.new(identifier: doi,
                                        errors: ["DataCite requires #{missing.join(', ')}"])
        end

        doi ||= mint_draft_doi
        submit_to_datacite(object, doi, serializer)
      rescue Hyrax::DOI::DataCiteClient::Error => e
        RegistrationResult.new(identifier: doi, errors: [e.message], response: e.errors)
      end

      def mint_draft_doi
        client.create_draft_doi
      end

      private

      # Creating a DOI asks the policy for permission; describing one the work already holds
      # only asks whether we may touch it. See MintingPolicy#updatable?.
      def register?(work)
        policy = Hyrax::DOI.config.minting_policy
        return policy.updatable?(work) if Array(work.try(:doi_value) || work.try(:doi)).first.present?

        policy.mintable?(work)
      end

      def public?(work)
        work.visibility == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      end

      def client
        @client ||= Hyrax::DOI::DataCiteClient.new(username: credentials.username,
                                                   password: credentials.password,
                                                   prefix: credentials.prefix,
                                                   mode: credentials.mode)
      end

      def submit_to_datacite(work, doi, serializer)
        record = client.put_doi(doi, attributes: serializer.to_attributes, event: event_for(work))
        RegistrationResult.new(identifier: record.doi || doi, state: record.state,
                               changed: true, response: record.attributes)
      end

      # The depositor's intent becomes one explicit state transition. A work intended to
      # be findable but not yet public is hidden rather than published, so it resolves for
      # anyone holding the DOI without being publicly indexed.
      def event_for(work)
        case work.doi_status_when_public
        when 'findable' then public?(work) ? DataCiteClient::EVENTS[:publish] : DataCiteClient::EVENTS[:hide]
        when 'registered' then DataCiteClient::EVENTS[:register]
        end
      end

      # Draft DOIs need no metadata; the other two states do.
      def requires_metadata?(work)
        work.doi_status_when_public.in?(%w[registered findable])
      end

      # NOTE: default_url_options[:host] must be set for this method to work
      def work_url(work)
        Rails.application.routes.url_helpers.polymorphic_url(work)
      end
    end
  end
end
