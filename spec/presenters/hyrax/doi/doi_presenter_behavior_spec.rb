# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DOIPresenterBehavior do
  subject(:presenter) { presenter_class.new(solr_document, nil) }

  let(:presenter_class) do
    Class.new(Hyrax::WorkShowPresenter) do
      include Hyrax::DOI::DOIPresenterBehavior
      include Hyrax::DOI::DataCiteDOIPresenterBehavior
    end
  end
  let(:solr_document_class) do
    Class.new(SolrDocument) do
      include Hyrax::DOI::SolrDocument::DOIBehavior
      include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior
    end
  end
  let(:solr_document) { solr_document_class.new(attributes) }
  let(:attributes) { { id: 'abc123' } }

  describe '#doi' do
    context 'when indexed' do
      let(:attributes) { { id: 'abc123', doi_ssim: ['10.5072/abc'] } }

      it 'reads the single value the show page needs' do
        expect(presenter.doi).to eq '10.5072/abc'
      end
    end

    it 'is nil when the work has none' do
      expect(presenter.doi).to be_nil
    end
  end

  describe '#doi_status' do
    context 'when the provider has reported a state' do
      let(:attributes) do
        { id: 'abc123', doi_state_ssi: 'registered', doi_status_when_public_ssi: 'findable' }
      end

      it 'reports what the provider says, not what was intended' do
        expect(presenter.doi_status).to eq 'registered'
      end
    end

    context 'when nothing has been registered yet' do
      let(:attributes) { { id: 'abc123', doi_status_when_public_ssi: 'findable' } }

      it 'falls back to the depositor s intent' do
        expect(presenter.doi_status).to eq 'findable'
      end
    end
  end

  describe '#doi_render_options' do
    let(:attributes) { { id: 'abc123', doi_state_ssi: 'draft' } }

    it 'passes the state through so the renderer can withhold a draft' do
      expect(presenter.doi_render_options)
        .to include(render_as: :doi, html_dl: true, doi_state: 'draft')
    end
  end
end
