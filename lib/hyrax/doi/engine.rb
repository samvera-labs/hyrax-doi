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
          inflect.acronym 'DataCite'
        end
      end

      config.after_initialize do
        Hyrax::CurationConcern.actor_factory.use Hyrax::Actors::DOIActor
      end
    end
  end
end
