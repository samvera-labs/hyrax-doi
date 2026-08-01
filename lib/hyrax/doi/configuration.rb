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
    end

    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield config
      end

      # Intended for tests.
      def reset_config!
        @config = nil
      end
    end
  end
end
