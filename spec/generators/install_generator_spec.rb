# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/install_generator'

describe Hyrax::DOI::InstallGenerator, type: :generator do
  # Tell the generator where to put its output (what it thinks of as Rails.root)
  destination Hyrax::DOI::Engine.root.join("tmp", "generator_testing")

  let(:solr_document_path) { File.join('app', 'models', 'solr_document.rb') }
  let(:routes_path) { File.join('config', 'routes.rb') }

  before do
    # This will wipe the destination root dir
    prepare_destination

    # Setup solr_document file in generator testing destination root dir
    FileUtils.mkdir_p destination_root.join(File.dirname(solr_document_path))
    FileUtils.cp Rails.root.join(solr_document_path), destination_root.join(solr_document_path)

    # Setup solr_document file in generator testing destination root dir
    FileUtils.mkdir_p destination_root.join(File.dirname(routes_path))
    FileUtils.cp Rails.root.join(routes_path), destination_root.join(routes_path)
  end

  describe 'generate_config' do
    it 'copies the initializer' do
      run_generator
      expect(file("config/initializers/hyrax-doi.rb")).to exist
    end

    # Everything the initializer offers is optional, and an app that never runs the
    # generator still mints DOIs. Anything active here would be a second place to
    # configure what the engine already wires.
    it 'writes nothing that executes' do
      run_generator

      body = File.read(File.join(destination_root, 'config/initializers/hyrax-doi.rb'))
      code = body.lines.grep_v(/^\s*#/).grep_v(/^\s*$/).join

      expect(code).to match(/\AHyrax::DOI\.configure do \|config\|\nend\n\z/)
    end
  end

  describe 'install_migrations' do
    it 'installs the table every minted identifier is recorded in' do
      run_generator

      migration = Dir.glob(File.join(destination_root, 'db/migrate/*create_hyrax_doi_persistent_identifiers.rb')).first
      expect(migration).to be_present
      expect(File.read(migration)).to include('create_table :hyrax_doi_persistent_identifiers')
    end
  end

  describe 'inject_into_solr_document' do
    it 'adds behavior module to solr_document' do
      run_generator
      expect(file(solr_document_path)).to contain('include Hyrax::DOI::SolrDocument::DOIBehavior')
    end

    context 'datacite enabled' do
      it 'adds behavior module to solr_document' do
        run_generator ["--datacite"]
        expect(file(solr_document_path)).to contain('include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior')
      end
    end
  end

  describe 'inject_engine_routes' do
    it 'mounts engine' do
      run_generator
      expect(file(routes_path)).to contain("mount Hyrax::DOI::Engine, at: '/doi'")
    end
  end
end
