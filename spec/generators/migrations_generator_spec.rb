# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/migrations_generator'

RSpec.describe Hyrax::DOI::MigrationsGenerator, type: :generator do
  destination Hyrax::DOI::Engine.root.join('tmp', 'generator_testing')

  before { prepare_destination }

  def migration
    Dir.glob(File.join(destination_root, 'db/migrate/*create_hyrax_doi_persistent_identifiers.rb')).first
  end

  it 'writes the migration' do
    run_generator

    expect(migration).to be_present
  end

  # The template interpolates migration_version, which Rails does not supply to a plain
  # generator -- without it the generator raises NameError instead of writing anything.
  it 'stamps the Rails version the migration inherits from' do
    run_generator

    expect(File.read(migration))
      .to match(/class CreateHyraxDoiPersistentIdentifiers < ActiveRecord::Migration\[\d+\.\d+\]/)
  end

  it 'creates the table the gem records identifiers in' do
    run_generator

    body = File.read(migration)
    expect(body).to include('create_table :hyrax_doi_persistent_identifiers')
    %w[resource_id scheme provider value state origin primary].each do |column|
      expect(body).to include(column)
    end
  end

  it 'indexes the lookup the gem does on every save' do
    run_generator

    expect(File.read(migration)).to match(/add_index .*resource_id.*scheme|index: /m)
  end
end
