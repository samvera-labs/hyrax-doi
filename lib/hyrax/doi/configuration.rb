# frozen_string_literal: true
module Hyrax
  module DOI
    class Configuration
      ##
      # Which provider mints each scheme, e.g. <tt>{ 'doi' => 'datacite' }</tt>.
      #
      # Provider is an institutional decision rather than a per-work editorial one, so
      # one default per scheme covers the common case. Per-work-type routing can layer
      # on top without changing this.
      attr_writer :default_providers

      def default_providers
        @default_providers ||= { 'doi' => 'datacite' }
      end

      def provider_for(scheme)
        default_providers[scheme.to_s]
      end

      attr_writer :credential_store

      def credential_store
        @credential_store ||= Hyrax::DOI::EnvCredentialStore.new
      end

      ##
      # Supply a DataCite value the work cannot simply be read for. A repository with no
      # creator field has to derive creators from its typed-role contributors, which no
      # profile mapping expresses. Called with the work; nil means read the field.
      attr_accessor :creator_extractor, :publisher_extractor

      attr_writer :minting_policy

      def minting_policy
        @minting_policy ||= Hyrax::DOI::MintingPolicy.new
      end
    end

    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield config
      end

      # Resolved per call rather than cached, so a request or job that has switched
      # tenants gets that tenant's credentials.
      def credentials_for(provider)
        config.credential_store.fetch(provider: provider)
      end

      def reset_config!
        @config = nil
      end
    end
  end
end
