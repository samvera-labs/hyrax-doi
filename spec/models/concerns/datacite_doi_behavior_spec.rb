# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::DataCiteDOIBehavior' do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior

      # Defined here for ActiveModel::Validations error messages
      def self.name
        "WorkWithDataCiteDOI"
      end
    end
  end
  let(:work) { model_class.new(title: ['Moomin']) }

  it_behaves_like 'a DOI-enabled model'
  it_behaves_like 'a DataCite DOI-enabled model'

  describe '#doi_registrar' do
    it 'returns :datacite' do
      expect(work.doi_registrar).to eq 'datacite'
    end
  end
end
