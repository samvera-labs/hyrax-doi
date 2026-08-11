# frozen_string_literal: true
require 'rails_helper'
# Generators are not automatically loaded by Rails
require 'generators/hyrax/doi/add_to_work_type_generator'

RSpec.describe Hyrax::DOI::AddToWorkTypeGenerator, type: :generator do
  destination Hyrax::DOI::Engine.root.join('tmp', 'generator_testing')

  let(:model_path) { 'app/models/monograph.rb' }
  let(:form_path) { 'app/forms/monograph_form.rb' }

  def write(path, content)
    full = File.join(destination_root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  # The shapes `rails generate hyrax:work_resource` produces.
  before do
    prepare_destination
    write model_path, <<~RUBY
      # frozen_string_literal: true
      class Monograph < Hyrax::Work
        include Hyrax::Schema(:basic_metadata)
      end
    RUBY
    write form_path, <<~RUBY
      # frozen_string_literal: true
      class MonographForm < Hyrax::Forms::ResourceForm(Monograph)
        include Hyrax::FormFields(:basic_metadata)
      end
    RUBY
  end

  describe 'the model' do
    it 'adds both concerns' do
      run_generator ['Monograph']

      expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
      expect(file(model_path)).to contain('include Hyrax::DOI::DataCiteDOIBehavior')
    end

    it 'adds only the base concern when DataCite is declined' do
      run_generator ['Monograph', '--no-datacite']

      expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
      expect(file(model_path)).not_to contain('DataCiteDOIBehavior')
    end
  end

  describe 'the form' do
    it 'adds both concerns' do
      run_generator ['Monograph']

      expect(file(form_path)).to contain('include Hyrax::DOI::DOIFormBehavior')
      expect(file(form_path)).to contain('include Hyrax::DOI::DataCiteDOIFormBehavior')
    end
  end

  # insert_into_file does not raise on a missing anchor, so a generator written against
  # the wrong class shape reports success while injecting nothing.
  it 'produces a model that parses' do
    run_generator ['Monograph']

    body = File.read(File.join(destination_root, model_path))
    expect(body).to match(/class Monograph < Hyrax::Work\n  include Hyrax::DOI::DOIBehavior\n/)
  end

  it 'says so rather than failing when a work type has no form' do
    FileUtils.rm_f File.join(destination_root, form_path)

    expect { run_generator ['Monograph'] }.not_to raise_error
    expect(file(model_path)).to contain('include Hyrax::DOI::DOIBehavior')
  end

  it 'does not double the concerns when run twice' do
    run_generator ['Monograph']
    run_generator ['Monograph']

    expect(File.read(File.join(destination_root, model_path)).scan('DOIBehavior').length).to eq 2
  end
end
