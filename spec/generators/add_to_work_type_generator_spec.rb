# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/add_to_work_type_generator'

describe Hyrax::DOI::AddToWorkTypeGenerator, type: :generator do
  # Tell the generator where to put its output (what it thinks of as Rails.root)
  destination Hyrax::DOI::Engine.root.join("tmp", "generator_testing")
  before do
    # This will wipe the destination root dir
    prepare_destination

    # Setup work type files in generator testing destination root dir
    # Model
    FileUtils.mkdir_p destination_root.join(File.dirname(model_path))
    FileUtils.cp Rails.root.join(model_path), destination_root.join(model_path)
    # Helper
    FileUtils.mkdir_p destination_root.join(File.dirname(form_path))
    FileUtils.cp Rails.root.join(form_path), destination_root.join(form_path)
  end

  let(:klass) { 'GenericWork' }
  let(:model_path) { File.join('app', 'models', "#{klass.underscore}.rb") }
  let(:form_path) { File.join('app', 'forms', 'hyrax', "#{klass.underscore}_form.rb") }

  describe 'inject_into_model' do
    it 'adds behavior module to model class' do
      run_generator [klass]
      expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
    end

    context 'with a namespaced model class' do
      let(:klass) { 'NamespacedWorks::NestedWork' }

      it 'adds behavior module to model class' do
        run_generator [klass]
        expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
      end
    end

    context 'datacite enabled' do
      it 'adds behavior module to model class' do
        run_generator [klass, "--datacite"]
        expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
        expect(file(model_path)).to contain('include Hyrax::DOI::DataCiteDOIBehavior')
      end

      context 'with a namespaced model class' do
        let(:klass) { 'NamespacedWorks::NestedWork' }

        it 'adds behavior module to model class' do
          run_generator [klass, "--datacite"]
          expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
          expect(file(model_path)).to contain('include Hyrax::DOI::DataCiteDOIBehavior')
        end
      end
    end
  end

  describe 'inject_into_form' do
    it 'adds behavior module to form class' do
      run_generator [klass]
      expect(file(form_path)).to contain('include Hyrax::DOI::DOIFormBehavior')
    end

    context 'with a namespaced model class' do
      let(:klass) { 'NamespacedWorks::NestedWork' }

      it 'adds behavior module to form class' do
        run_generator [klass]
        expect(file(form_path)).to contain('include Hyrax::DOI::DOIFormBehavior')
      end
    end

    context 'datacite enabled' do
      it 'adds behavior module to form class' do
        run_generator [klass, "--datacite"]
        expect(file(form_path)).to contain('include Hyrax::DOI::DOIFormBehavior')
        expect(file(form_path)).to contain('include Hyrax::DOI::DataCiteDOIFormBehavior')
      end

      context 'with a namespaced model class' do
        let(:klass) { 'NamespacedWorks::NestedWork' }

        it 'adds behavior module to form class' do
          run_generator [klass, "--datacite"]
          expect(file(form_path)).to contain('include Hyrax::DOI::DOIFormBehavior')
          expect(file(form_path)).to contain('include Hyrax::DOI::DataCiteDOIFormBehavior')
        end
      end
    end
  end
end
