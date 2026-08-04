# frozen_string_literal: true
module Hyrax
  module DOI
    # What a provider needs to authenticate. Resolved per call; see
    # DataCiteRegistrar#initialize for why these are not class state.
    Credentials = Data.define(:provider, :prefix, :username, :password, :mode) do
      def initialize(provider:, prefix: nil, username: nil, password: nil, mode: nil)
        super
      end

      # Symbolized because a store may hand back either, and callers compare against
      # :production. Defaults to test so a misconfiguration cannot mint real DOIs.
      def mode
        (to_h[:mode].presence || :test).to_sym
      end

      def production?
        mode == :production
      end

      def complete?
        [prefix, username, password].all?(&:present?)
      end

      # Redacted so credentials cannot reach a log, an exception report, or a job payload
      # by way of a stray inspect.
      def inspect
        "#<data Hyrax::DOI::Credentials provider=#{provider.inspect} prefix=#{prefix.inspect} " \
          "username=#{username.inspect} password=[REDACTED] mode=#{mode.inspect}>"
      end
      alias_method :to_s, :inspect
    end
  end
end
