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
        expect(helper_object.form_tabs_for(form:))
          .to eq %w[doi metadata files relationships]
      end
    end

    context 'when the work has no doi attribute' do
      let(:work) { Object.new }

      it 'leaves the tabs alone' do
        expect(helper_object.form_tabs_for(form:))
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
        expect(helper_object.form_tabs_for(form:)).to include('doi')
      end
    end
  end

  describe '#doi_required_fields' do
    # A real Valkyrie resource, so the helper cannot rely on a method no work type has.
    let(:work_class) do
      Class.new(Hyrax::Work) do
        def self.name = 'RequiredFieldsWork'
        attribute :publisher, Valkyrie::Types::Array.of(Valkyrie::Types::String)
        include Hyrax::DOI::DOIBehavior
      end
    end
    let(:work) { work_class.new }
    let(:form) do
      instance_double(Hyrax::Forms::ResourceForm,
                      model: work,
                      model_name: ActiveModel::Name.new(nil, nil, 'Monograph'))
    end

    before { stub_const('RequiredFieldsWork', work_class) }

    it 'names the required fields the work has' do
      fields = helper_object.doi_required_fields(form)

      expect(fields.pluck(:selector)).to include('.monograph_title', '.monograph_publisher')
    end

    # Derived rather than hardcoded: which attributes a work carries differs between flex
    # modes, so naming a specific absent field would assert the mode, not the filtering.
    it 'omits required fields the work does not have' do
      absent = Hyrax::DOI::DataCiteSerializer.required_work_fields.reject { |f| work.respond_to?(f) }
      fields = helper_object.doi_required_fields(form)

      expect(fields.pluck(:selector)).to match_array(
        (Hyrax::DOI::DataCiteSerializer.required_work_fields - absent).map { |f| ".monograph_#{f}" }
      )
    end

    it 'labels each field without ActiveModel' do
      labels = helper_object.doi_required_fields(form).pluck(:label)

      expect(labels).to all(be_present)
      expect(labels).to include('Publisher')
    end
  end
end
