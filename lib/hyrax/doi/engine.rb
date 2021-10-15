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
        all_paths = ActionController::Base.view_paths.collect(&:to_s)
        hyrax_path = all_paths.detect { |path| path.match(/\/hyrax-[\d\.]+.*/) }
        all_paths = if hyrax_path
                  all_paths.insert(all_paths.index(hyrax_path), paths['app/views'].existent)
                else
                  all_paths.insert(1, paths['app/views'].existent)
                end
        ActionController::Base.view_paths = all_paths
      end
    end
  end
end
