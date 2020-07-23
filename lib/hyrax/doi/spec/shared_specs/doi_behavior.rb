# frozen_string_literal: true
RSpec.shared_examples "a DOI-enabled model" do
  subject { work }

  let(:properties) do
    [:doi,
     :doi_status_when_public]
  end

  describe "properties" do
    it "has DOI properties" do
      properties.each do |property|
        expect(subject).to respond_to(property)
      end
    end
  end

  describe 'validations' do
    describe 'validates format of doi' do
      let(:valid_dois) { [nil, '10.1234/abc', '10.1234.100/abc-def', '10.1234/1', '10.1234/doi/with/more/slashes'] }
      let(:invalid_dois) { ['10.123/abc', 'https://doi.org/10.1234/abc', '10.1234/abc def', ''] }

      it 'accepts valid dois' do
        valid_dois.each do |valid_doi|
          expect(subject).to allow_value(valid_doi).for(:doi)
        end
      end

      it 'rejects invalid dois' do
        invalid_dois.each do |invalid_doi|
          expect(subject).not_to allow_values(invalid_doi).for(:doi)
        end
      end
    end

    it 'validates inclusion of doi_status_when_public' do
      expect(subject).to validate_inclusion_of(:doi_status_when_public).in_array([nil, :draft, :registered, :findable]).allow_nil
    end
  end

  describe 'to_solr' do
    let(:solr_doc) { subject.to_solr }

    let(:solr_fields) do
      [:doi_ssi,
       :doi_status_when_public_ssi]
    end

    before do
      work.doi = "10.1234/abc"
      work.doi_status_when_public = :draft
    end

    it 'has solr fields' do
      solr_fields.each do |field|
        expect(solr_doc.fetch(field.to_s)).not_to be_blank
      end
    end
  end
end
