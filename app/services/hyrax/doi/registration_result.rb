# frozen_string_literal: true
module Hyrax
  module DOI
    # What a registrar returns from #register!.
    #
    # Hyrax::Identifier::Registrar's contract is only "returns something responding to
    # #identifier", which cannot express state, failure, or "nothing needed doing".
    # Callers need all three: to write state back to the PID record, to report status
    # in the admin UI, and to distinguish a skip from an error.
    class RegistrationResult
      attr_reader :identifier, :state, :errors, :response

      delegate :to_s, to: :identifier

      ##
      # @param state [String, nil] provider vocabulary, stored verbatim
      # @param changed [Boolean] whether anything was sent to the provider
      def initialize(identifier: nil, state: nil, changed: false, errors: [], response: nil)
        @identifier = identifier
        @state = state
        @changed = changed
        @errors = Array(errors)
        @response = response
      end

      ##
      # A skipped registration is a success: the work was not eligible, or nothing
      # had changed.
      def success?
        @errors.empty?
      end

      def failure?
        !success?
      end

      def changed?
        @changed
      end

      def error_message
        @errors.join('; ').presence
      end
    end
  end
end
