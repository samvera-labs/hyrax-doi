# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::DOIBehavior' do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
    end
  end
  let(:work) { model_class.new(title: ['Moomin']) }

  before do
    # Stubbed here for ActiveModel::Validations error messages
    stub_const("WorkWithDOI", model_class)
  end

  it_behaves_like 'a DOI-enabled model'
end
