# frozen_string_literal: true
module Hyrax
  module DOI
    class Engine < ::Rails::Engine
      isolate_namespace Hyrax::DOI

      config.before_configuration do
        # Fix camelizing of paths for autoloading
        # With this hyrax/doi/application_helper -> Hyrax::DOI::ApplicationHelper
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym 'DOI'
        end
      end

      config.after_initialize do
        # Hyrax::CurationConcern.actor_factory.use Hyrax::Actors::DOIActor
        # TODO: make this additive and put it somewhere where it can be modified or overridden; maybe in the generator?
        Hyrax.config.identifier_registrars = { datacite: Hyrax::DOI::DataciteRegistrar }
      end
    end
  end
end
