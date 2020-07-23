# frozen_string_literal: true
require 'rails/generators'
require 'rails/generators/model_helpers'

module Hyrax
  module DOI
    class AddToWorkTypeGenerator < Rails::Generators::NamedBase
      # ActiveSupport can interpret models as plural which causes
      # counter-intuitive route paths. Pull in ModelHelpers from
      # Rails which warns users about pluralization when generating
      # new models or scaffolds.
      include Rails::Generators::ModelHelpers

      # Required due to non-standard capitalization of DOI namespace
      namespace 'hyrax:doi:add_to_work_type'
      # Same as adding --skip-namespace flag to generator call
      # This removes the hyrax/doi namespace from class_path
      # Namespaces passed as the argument will still appear in class_path
      class_option :skip_namespace, default: true

      desc "Add DOI support to given work type"

      def inject_into_model
        # For some reason I had to use self.destination_root here to get all contexts to work (calling from hyrax app, calling from this engine to test app, rspec tests)
        # rubocop:disable Style/RedundantSelf
        self.destination_root = Rails.root if self.destination_root.blank? || self.destination_root == Hyrax::DOI::Engine.root.to_s
        model_file = File.join(self.destination_root, 'app', 'models', *class_path, "#{file_name}.rb")
        # rubocop:enable Style/RedundantSelf

        insert_into_file model_file, after: 'include ::Hyrax::WorkBehavior' do
          "\n" \
          "  # Adds behaviors for hyrax-doi plugin.\n" \
          "  include Hyrax::DOI::DOIBehavior"
        end
      end
    end
  end
end
