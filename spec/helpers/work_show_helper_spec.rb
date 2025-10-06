# frozen_string_literal: true
require 'rails_helper'

describe 'Hyrax::DOI::WorkFormHelper' do
  describe 'render_doi?' do
    let(:doi_presenter_class) do
      Class.new(Hyrax::GenericWorkPresenter) do
        include Hyrax::DOI::DOIPresenterBehavior
      end
    end
    let(:datacite_presenter_class) do
      Class.new(Hyrax::GenericWorkPresenter) do
        include Hyrax::DOI::DOIPresenterBehavior
        include Hyrax::DOI::DataCiteDOIPresenterBehavior
      end
    end
    let(:non_doi_presenter_class) { Hyrax::GenericWorkPresenter }
    let(:solr_document_class) do
      Class.new(SolrDocument) do
        include Hyrax::DOI::SolrDocument::DOIBehavior
        include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior

        def flexible?
          false
        end
      end
    end
    let(:presenter) { presenter_class.new(solr_document, nil, nil) }
    let(:solr_document) do
      doc_double = instance_double(solr_document_class)
      allow(doc_double).to receive(:flexible?).and_return(false)
      doc_double
    end

    # Override rspec-rails defined helper
    # This allow us to inject HyraxHelper which is being overriden
    # so super is defined.
    let(:helper) do
      _view.tap do |v|
        v.extend(ApplicationHelper)
        v.extend(HyraxHelper)
        v.extend(Hyrax::DOI::HelperBehavior)
        v.assign(view_assigns)
      end
    end

    context 'with a DOI-enabled model' do
      let(:presenter_class) { doi_presenter_class }

      it 'returns true' do
        expect(helper.render_doi?(presenter)).to eq true
      end
    end

    context 'with a DataCite DOI-enabled presenter' do
      let(:presenter_class) { datacite_presenter_class }

      context 'with findable doi status' do
        before do
          allow(solr_document).to receive(:doi_status_when_public).and_return('findable')
        end

        it 'returns true' do
          expect(helper.render_doi?(presenter)).to eq true
        end
      end

      context 'with draft doi status' do
        before do
          allow(solr_document).to receive(:doi_status_when_public).and_return('draft')
        end

        it 'returns false' do
          expect(helper.render_doi?(presenter)).to eq false
        end
      end

      context 'with doi status not set' do
        before do
          allow(solr_document).to receive(:doi_status_when_public).and_return(nil)
        end

        it 'returns true' do
          expect(helper.render_doi?(presenter)).to eq true
        end
      end
    end

    context 'with a non-DOI-enabled model' do
      let(:presenter_class) { non_doi_presenter_class }

      it 'returns false' do
        expect(helper.render_doi?(presenter)).to eq false
      end
    end
  end
end
