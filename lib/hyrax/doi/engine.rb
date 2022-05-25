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

      # Allow flipflop to load config/features.rb from the Hyrax gem:
      initializer 'configure' do
        Flipflop::FeatureLoader.current.append(self)
      end

      config.after_initialize do
        Hyrax::CurationConcern.actor_factory.use Hyrax::Actors::DOIActor

        require 'bolognese'
        Bolognese::Metadata.prepend Bolognese::Readers::HyraxWorkReader
        Bolognese::Metadata.prepend Bolognese::Writers::HyraxWorkWriter

        # Prepend our views in front of Hyrax but after the main app, so they have precedence
        # but can still be overridden
        my_engine_root = Hyrax::DOI::Engine.root.to_s
        paths = ActionController::Base.view_paths.collect(&:to_s)
        hyrax_path = paths.detect { |path| path.match(/\/hyrax-[\d\.]+.*/) }
        paths = if hyrax_path
                  paths.insert(paths.index(hyrax_path), my_engine_root + '/app/views')
                else
                  paths.insert(0, my_engine_root + '/app/views')
                end
        ActionController::Base.view_paths = paths
      end
    end
  end
end
