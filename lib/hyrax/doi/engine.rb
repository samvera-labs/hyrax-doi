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

      # Registers itself so installing the gem is enough. Hyrax ships an empty registrar
      # hash and its own generator only writes one into a host initializer, which is easy
      # to skip and leaves minting silently unavailable.
      initializer 'hyrax_doi.register_registrars' do
        config.to_prepare do
          Hyrax.config.identifier_registrars =
            { datacite: Hyrax::DOI::DataCiteRegistrar }.merge(Hyrax.config.identifier_registrars)
        end
      end

      # Lets a non-flex application `include Hyrax::Schema(:doi)` and pick up
      # config/metadata/doi.yaml from this gem. Unshifted so the application can still
      # shadow it with its own doi.yaml -- first match wins.
      initializer 'hyrax_doi.schema_search_path' do
        root = Hyrax::DOI::Engine.root
        paths = Hyrax.config.schema_loader_config_search_paths
        paths.unshift(root) unless paths.include?(root)
      end

      # to_prepare rather than after_initialize so the prepend survives a dev reload,
      # which discards and redefines the Hyrax constant.
      config.to_prepare do
        require 'hyrax/doi/flexible_schema_validator_service_decorator'

        decorator = Hyrax::DOI::FlexibleSchemaValidatorServiceDecorator
        service = Hyrax::FlexibleSchemaValidatorService
        service.prepend(decorator) unless service.ancestors.include?(decorator)
      end

      # Contributes the DOI tab and the mint action to Hyrax's helper seams. Wired here
      # rather than left to the install generator: a host that skips the generator would
      # otherwise get a working registrar with no UI reaching it.
      config.to_prepare do
        # Prepended, not included, so form_tabs_for and show_actions_for reach Hyrax's
        # implementations through super. A plain helper include would replace each method
        # rather than wrap it, dropping both Hyrax's tabs and any other engine's actions.
        { Hyrax::WorkFormHelper => Hyrax::DOI::WorkFormHelper,
          Hyrax::WorksHelper => Hyrax::DOI::MintButtonHelper }.each do |target, mod|
          target.prepend(mod) unless target.ancestors.include?(mod)
        end

        ActionController::Base.helper(Hyrax::DOI::WorkShowHelper)
      end

      config.after_initialize do
        Hyrax::CurationConcern.actor_factory.use Hyrax::Actors::DOIActor

        # Prepend our views in front of Hyrax but after the main app, so they have precedence
        # but can still be overridden
        my_engine_root = Hyrax::DOI::Engine.root.to_s
        hyrax_engine_root = Hyrax::Engine.root.to_s
        paths = ActionController::Base.view_paths.collect(&:to_s)
        hyrax_view_path = paths.detect { |path| path.match(%r{^#{hyrax_engine_root}}) }
        paths.insert(paths.index(hyrax_view_path), File.join(my_engine_root, 'app', 'views')) if hyrax_view_path

        ActionController::Base.view_paths = paths.uniq
      end
    end
  end
end
