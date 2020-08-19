# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::SolrDocument::DataCiteDOIBehavior' do
  let(:solr_document_class) do
    Class.new(SolrDocument) do
      include Hyrax::DOI::SolrDocument::DOIBehavior
      include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior
    end
  end

  it_behaves_like 'a DOI-enabled solr document'
  it_behaves_like 'a DataCite DOI-enabled solr document'
end
