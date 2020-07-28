module Hyrax
  module DOI
    class RegisterDOIJob < ApplicationJob
      ##
      # @!attribute [rw] registrar_opts
      attr_writer :registrar, :registrar_opts

      def registrar
        @registrar ||= Hyrax.config.identifier_registrars.keys.first
      end

      def registrar_opts
        @registrar_opts ||= {}
      end

      queue_as :doi_service

      ##
      # @param model [ActiveFedora::Base]
      def perform(model)
        Hyrax::Identifier::Dispatcher
          .for(registrar, **registrar_opts)
          .assign_for!(object: model, attribute: :doi)
      end
    end
  end
end