# frozen_string_literal: true
module Hyrax
  module DOI
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception

      def self.search_state_class=(*)
        # no-op to make Hyrax::Controller happy
      end

      # Include after search_state_class is defined since Hyrax::Controller calls it
      include Hyrax::Controller
    end
  end
end
