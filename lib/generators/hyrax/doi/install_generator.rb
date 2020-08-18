# frozen_string_literal: true
require 'rails/generators'
require 'rails/generators/model_helpers'

module Hyrax
  module DOI
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      # Required due to non-standard capitalization of DOI namespace
      namespace 'hyrax:doi:install'
      # Same as adding --skip-namespace flag to generator call
      # This removes the hyrax/doi namespace from class_path
      # Namespaces passed as the argument will still appear in class_path
      class_option :skip_namespace, default: true

      # DataCite-specific support
      class_option :datacite, type: :boolean, default: false, desc: "Add DataCite-specific behavior."

      def generate_config
        # rubocop:disable Style/RedundantSelf
        # For some reason I had to use self.destination_root here to get all contexts to work (calling from hyrax app, calling from this engine to test app, rspec tests)
        self.destination_root = Rails.root if self.destination_root.blank? || self.destination_root == Hyrax::DOI::Engine.root.to_s
        initializer_file = File.join(self.destination_root, 'config', 'initializers', 'hyrax-doi.rb')
        # rubocop:enable Style/RedundantSelf

        copy_file "config/initializers/hyrax-doi.rb", initializer_file
      end

      def inject_into_helper
        # rubocop:disable Style/RedundantSelf
        # For some reason I had to use self.destination_root here to get all contexts to work (calling from hyrax app, calling from this engine to test app, rspec tests)
        self.destination_root = Rails.root if self.destination_root.blank? || self.destination_root == Hyrax::DOI::Engine.root.to_s
        helper_file = File.join(self.destination_root, 'app', 'helpers', "hyrax_helper.rb")
        # rubocop:enable Style/RedundantSelf

        insert_into_file helper_file, after: 'include Hyrax::HyraxHelperBehavior' do
          "\n" \
          "  # Overrides #form_tabs_for for DOI tab provided by hyrax-doi plugin.\n" \
          "  include Hyrax::DOI::WorkFormHelper"
        end
      end
    end
  end
end
