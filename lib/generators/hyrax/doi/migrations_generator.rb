# frozen_string_literal: true
require 'rails/generators'
require 'rails/generators/active_record'

module Hyrax
  module DOI
    # A generator rather than an engine migration, so adopters are not handed a
    # migration they did not ask for and can place the table where they choose.
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      # Required due to non-standard capitalization of the DOI namespace
      namespace 'hyrax:doi:migrations'
      class_option :skip_namespace, default: true

      desc 'Install hyrax-doi migrations'
      def create_migrations
        migration_template 'db/migrate/create_hyrax_doi_persistent_identifiers.rb.erb',
                           'db/migrate/create_hyrax_doi_persistent_identifiers.rb'
      end
    end
  end
end
