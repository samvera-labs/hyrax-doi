# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::WorkFormHelper do
  subject(:helper_object) do
    Class.new do
      def form_tabs_for(form:) # rubocop:disable Lint/UnusedMethodArgument
        %w[metadata files relationships]
      end
      prepend Hyrax::DOI::WorkFormHelper
    end.new
  end

  let(:form) { instance_double(Hyrax::Forms::ResourceForm, model: work) }

  describe '#form_tabs_for' do
    context 'when the work carries a doi attribute' do
      let(:work) { Struct.new(:doi).new(nil) }

      it 'puts the DOI tab first' do
        expect(helper_object.form_tabs_for(form: form))
          .to eq %w[doi metadata files relationships]
      end
    end

    context 'when the work has no doi attribute' do
      let(:work) { Object.new }

      it 'leaves the tabs alone' do
        expect(helper_object.form_tabs_for(form: form))
          .to eq %w[metadata files relationships]
      end
    end

    # Under HYRAX_FLEXIBLE an m3 profile puts attributes on the instance's singleton
    # class, so the work responds to doi while its class does not declare it.
    context 'when doi comes from a profile rather than the class' do
      let(:work_class) { Class.new }
      let(:work) do
        work_class.new.tap do |instance|
          instance.singleton_class.define_method(:doi) { nil }
        end
      end

      it 'still offers the tab' do
        expect(work_class.instance_methods).not_to include(:doi)
        expect(helper_object.form_tabs_for(form: form)).to include('doi')
      end
    end
  end

  describe '#doi_required_fields' do
    let(:work) { Struct.new(:doi, :title, :publisher).new(nil, nil, nil) }
    let(:form) do
      instance_double(Hyrax::Forms::ResourceForm,
                      model: work,
                      model_class: work_class,
                      model_name: ActiveModel::Name.new(nil, nil, 'Monograph'))
    end
    let(:work_class) do
      Class.new do
        def self.human_attribute_name(field) = field.to_s.titleize
      end
    end

    it 'names only fields the work actually has' do
      fields = helper_object.doi_required_fields(form)

      expect(fields).to include(hash_including(selector: '.monograph_title', label: 'Title'))
      expect(fields.map { |f| f[:selector] }).not_to include('.monograph_creator')
    end
  end
end
