# frozen_string_literal: true
module Hyrax
  module DOI
    # Where credentials come from. Subclass and register via
    # +Hyrax::DOI.config.credential_store+ to read them from somewhere else -- a
    # per-tenant record, Vault, Rails credentials.
    #
    # The gem deliberately ships no persistence model: a host that already stores
    # provider credentials should not be handed a second place to keep them.
    class CredentialStore
      class ReadOnlyError < Hyrax::DOI::Error; end

      # What each provider needs, described rather than hardcoded, so a form can render
      # itself from this and adding a provider does not mean editing a view.
      FIELD_SCHEMAS = {
        'datacite' => [
          { name: :prefix, type: :string, required: true },
          { name: :username, type: :string, required: true },
          { name: :password, type: :string, required: true, secret: true },
          { name: :mode, type: :select, required: true, options: %w[test production], default: 'test' }
        ].freeze
      }.freeze

      def self.field_schema_for(provider)
        FIELD_SCHEMAS.fetch(provider.to_s, [])
      end

      def fetch(provider:)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end

      def store(provider:, attributes:)
        raise ReadOnlyError, "#{self.class} cannot write #{provider} credentials " \
                             "(#{attributes.keys.join(', ')})"
      end

      def writable?
        false
      end
    end

    # Reads from the environment, e.g. DATACITE_PREFIX. Enough for a single-tenant
    # application; a multi-tenant host replaces it.
    class EnvCredentialStore < CredentialStore
      def fetch(provider:)
        env = provider.to_s.upcase
        Credentials.new(provider: provider.to_s,
                        prefix: ENV.fetch("#{env}_PREFIX", nil),
                        username: ENV.fetch("#{env}_USERNAME", nil),
                        password: ENV.fetch("#{env}_PASSWORD", nil),
                        mode: ENV.fetch("#{env}_MODE", nil))
      end
    end
  end
end
