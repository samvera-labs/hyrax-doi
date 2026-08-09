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

      class_option :datacite, type: :boolean, default: false, desc: "Add DataCite-specific behavior."

      def generate_config
        copy_file 'config/initializers/hyrax-doi.rb', app_path('config', 'initializers', 'hyrax-doi.rb')
      end

      # Every identifier the gem records lives in this table, so minting raises without
      # it. Installed here rather than left to a separate step an adopter can miss.
      #
      # invoke, not generate: the latter shells out to bin/rails, which is absent when the
      # generator runs anywhere but an application root.
      def install_migrations
        invoke 'hyrax:doi:migrations', [], destination_root: destination_root
      end

      def inject_into_solr_document
        solr_document_file = app_path('app', 'models', 'solr_document.rb')

        insert_into_file solr_document_file, after: 'include Hyrax::SolrDocumentBehavior' do
          "\n" \
          "  # Add attributes for DOIs for hyrax-doi plugin.\n" \
          "  include Hyrax::DOI::SolrDocument::DOIBehavior"
        end

        return unless options[:datacite]

        insert_into_file solr_document_file, after: 'Hyrax::DOI::SolrDocument::DOIBehavior' do
          "\n" \
          "  # Add attributes for DataCite DOIs for hyrax-doi plugin.\n" \
          "  include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior"
        end
      end

      def mount_engine_routes
        inject_into_file 'config/routes.rb', after: /mount Hyrax::Engine, at: '\S*'\n/ do
          "  mount Hyrax::DOI::Engine, at: '/doi', as: 'hyrax_doi'\n"
        end
      end

      private

      # destination_root is the engine's own root when the generator is invoked from within
      # the engine -- running the suite, or a developer trying it out -- so fall back to the
      # application it is being installed into.
      def app_path(*segments)
        root = destination_root
        root = Rails.root.to_s if root.blank? || root == Hyrax::DOI::Engine.root.to_s
        File.join(root, *segments)
      end
    end
  end
end
