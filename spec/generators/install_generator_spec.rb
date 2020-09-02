# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/install_generator'

describe Hyrax::DOI::InstallGenerator, type: :generator do
  # Tell the generator where to put its output (what it thinks of as Rails.root)
  destination Hyrax::DOI::Engine.root.join("tmp", "generator_testing")

  let(:helper_path) { File.join('app', 'helpers', 'hyrax_helper.rb') }
  let(:solr_document_path) { File.join('app', 'models', 'solr_document.rb') }
  let(:routes_path) { File.join('config', 'routes.rb') }

  before do
    # This will wipe the destination root dir
    prepare_destination

    # Setup helper file in generator testing destination root dir
    FileUtils.mkdir_p destination_root.join(File.dirname(helper_path))
    FileUtils.cp Rails.root.join(helper_path), destination_root.join(helper_path)

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
  end

  describe 'inject_into_helper' do
    it 'adds behavior module to helper' do
      run_generator
      expect(file(helper_path)).to contain('include Hyrax::DOI::HelperBehavior')
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
