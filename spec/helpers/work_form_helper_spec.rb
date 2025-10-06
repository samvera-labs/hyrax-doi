# frozen_string_literal: true
require 'rails_helper'

describe 'Hyrax::DOI::WorkFormHelper' do
  describe 'form_tabs_for' do
    let(:model_class) do
      Class.new(GenericWork) do
        include Hyrax::DOI::DOIBehavior

        # Defined here for ActiveModel::Validations error messages
        def self.name
          "WorkWithDOI"
        end
      end
    end
    let(:work) { model_class.new(title: ['Moomin']) }
    let(:form_class) do
      Class.new(Hyrax::GenericWorkForm) do
        include Hyrax::DOI::DOIFormBehavior

        self.model_class = WorkWithDOI
      end
    end
    let(:form) { form_class.new(work, nil, nil) }

    # Override rspec-rails defined helper
    # This allow us to inject HyraxHelper which is being overriden
    # so super is defined.
    let(:helper) do
      _view.tap do |v|
        v.extend(ApplicationHelper)
        v.extend(HyraxHelper)
        v.extend(Hyrax::DOI::WorkFormHelper)
        v.assign(view_assigns)
      end
    end

    context 'with a DOI-enabled model' do
      before do
        # Stubbed here for form class's model_class attribute
        stub_const("WorkWithDOI", model_class)
      end

      it 'adds doi tab' do
        expect(helper.form_tabs_for(form:)).to include('doi')
      end
    end

    context 'with a non-DOI-enabled model' do
      # Create a clean class that definitely doesn't include DOI behavior
      let(:clean_model_class) do
        Class.new(GenericWork) do
          # Explicitly define a clean model class without DOI behavior
          def self.name
            "CleanGenericWork"
          end
        end
      end

      let(:clean_form_class) do
        clean_class = clean_model_class
        Class.new(Hyrax::GenericWorkForm) do
          self.model_class = clean_class
        end
      end

      let(:work) { clean_model_class.new(title: ['Moomin']) }
      let(:form) { clean_form_class.new(work, nil, nil) }

      before do
        # Stub a clean constant to ensure isolation
        stub_const("CleanGenericWork", clean_model_class)
      end

      it 'does not add doi tab' do
        expect(helper.form_tabs_for(form:)).not_to include('doi')
      end
    end
  end
end
