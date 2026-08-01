# frozen_string_literal: true
module Hyrax
  module DOI
    ##
    # Identifiers that are recorded rather than minted -- ORCID, ROR, ISNI.
    #
    # These have no +register!+: nothing is created at a provider, so forcing them
    # through Hyrax::Identifier::Registrar would misrepresent them. They need
    # validation, normalization, and a resolver URL instead.
    #
    # Subclasses define PATTERN and RESOLVER, and may override #normalize.
    class RecordedIdentifier
      class << self
        def registry
          @registry ||= {}
        end

        def register(scheme, klass)
          registry[scheme.to_s] = klass
        end

        def for(scheme)
          registry[scheme.to_s]&.new
        end
      end

      def pattern
        self.class::PATTERN
      end

      def resolver
        self.class::RESOLVER
      end

      def valid?(value)
        normalize(value).to_s.match?(pattern)
      end

      ##
      # Strips a resolver prefix so a pasted URL and a bare identifier compare equal.
      def normalize(value)
        return nil if value.blank?

        value.to_s.strip.sub(%r{\Ahttps?://[^/]+/}, '')
      end

      def resolve_url(value)
        normalized = normalize(value)
        return nil if normalized.blank?

        "#{resolver}#{normalized}"
      end
    end

    ##
    # https://info.orcid.org/documentation/integration-guide/orcid-identifier/
    # Sixteen digits in four groups; the final character may be X.
    class ORCIDIdentifier < RecordedIdentifier
      PATTERN = /\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/
      RESOLVER = 'https://orcid.org/'
    end

    ##
    # https://ror.readme.io/docs/identifier
    # A base32-encoded value prefixed with 0, plus a two-digit checksum.
    class RORIdentifier < RecordedIdentifier
      PATTERN = /\A0[a-hj-km-np-tv-z0-9]{6}\d{2}\z/
      RESOLVER = 'https://ror.org/'
    end

    RecordedIdentifier.register('orcid', ORCIDIdentifier)
    RecordedIdentifier.register('ror', RORIdentifier)
  end
end
