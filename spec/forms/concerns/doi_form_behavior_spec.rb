# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::DOIFormBehavior' do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
    end
  end
  let(:work) { model_class.new(title: ['Moomin']) }
  let(:form_class) do
    Class.new(Hyrax::GenericWorkForm) do
      include Hyrax::DOI::DOIFormBehavior
    end
  end
  let(:form) { form_class.new(work, nil, nil) }

  it_behaves_like 'a DOI-enabled form'
end
