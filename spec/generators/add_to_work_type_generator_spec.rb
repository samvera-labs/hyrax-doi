# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/add_to_work_type_generator'

def model_path
  File.join('app', 'models', "#{klass.underscore}.rb")
end

describe Hyrax::DOI::AddToWorkTypeGenerator, type: :generator do
  # Tell the generator where to put its output (what it thinks of as Rails.root)
  destination Hyrax::DOI::Engine.root.join("tmp", "generator_testing")
  before do
    # This will wipe the destination root dir
    prepare_destination

    # Setup work type files in generator testing destination root dir
    FileUtils.mkdir_p destination_root.join(File.dirname(model_path))
    FileUtils.cp Rails.root.join(model_path), destination_root.join(model_path)
  end

  let(:klass) { 'GenericWork' }

  it 'adds behavior module to model class' do
    run_generator [klass]
    expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
  end

  context 'with a namespaced model class' do
    let(:klass) { 'NamespacedWorks::NestedWork' }

    it 'adds behavior module tod model class' do
      run_generator [klass]
      expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
    end
  end
end
