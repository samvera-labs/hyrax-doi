# frozen_string_literal: true
module Hyrax
  module DOI
    # The outcome of a connection test: whether the provider answered, a message fit to
    # display, and when it was checked.
    PingResult = Data.define(:success, :message, :checked_at) do
      def initialize(success:, message: nil, checked_at: Time.current)
        super
      end

      def success? = success
      def failure? = !success
    end
  end
end
