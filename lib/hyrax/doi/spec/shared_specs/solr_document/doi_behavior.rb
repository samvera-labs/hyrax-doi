# frozen_string_literal: true
RSpec.shared_examples "a DOI-enabled solr document" do
  let(:document) { solr_document_class.new(attributes) }
  let(:attributes) { {} }

  describe "doi" do
    it 'is empty if not present' do
      expect(document.doi).to be_blank
    end

    context 'when present' do
      let(:doi) { '10.1234/abc' }
      let(:attributes) { { doi_ssim: [doi] } }

      it 'returns the doi' do
        expect(document.doi).to eq [doi]
      end
    end

    describe 'doi_state' do
      let(:attributes) { { doi_state_ssi: 'findable' } }

      it 'exposes what the provider last reported' do
        expect(document.doi_state).to eq 'findable'
      end
    end
  end
end
