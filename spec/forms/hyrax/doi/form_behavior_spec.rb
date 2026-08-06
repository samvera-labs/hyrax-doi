# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

RSpec.describe 'DOI form behaviors' do
  let(:work_class) do
    Class.new(Hyrax::Work) do
      def self.name = 'FormBehaviorWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end
  end
  let(:work) { work_class.new(title: ['Moomin']) }

  before { stub_const('FormBehaviorWork', work_class) }

  describe Hyrax::DOI::DOIFormBehavior do
    let(:form_class) do
      Class.new(Hyrax::Forms::ResourceForm(FormBehaviorWork)) do
        include Hyrax::DOI::DOIFormBehavior
      end
    end
    let(:form) { form_class.new(work) }

    it_behaves_like 'a DOI-enabled form'
  end

  describe Hyrax::DOI::DataCiteDOIFormBehavior do
    let(:form_class) do
      Class.new(Hyrax::Forms::ResourceForm(FormBehaviorWork)) do
        include Hyrax::DOI::DOIFormBehavior
        include Hyrax::DOI::DataCiteDOIFormBehavior
      end
    end
    let(:form) { form_class.new(work) }

    it_behaves_like 'a DOI-enabled form'
    it_behaves_like 'a DataCite DOI-enabled form'
  end
end
