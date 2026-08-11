# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::FlexibleSchemaValidators::DOIValidator do
  subject(:validator) { described_class.new(profile:, errors:, warnings:) }

  let(:errors) { [] }
  let(:warnings) { [] }

  let(:profile_with_doi) do
    {
      'classes' => { 'Monograph' => {} },
      'properties' => {
        'doi' => {
          'type' => 'string',
          'available_on' => { 'class' => ['Monograph'] },
          'view' => { 'render_as' => 'doi', 'html_dl' => true }
        }
      }
    }
  end

  # The attribute may be declared on the work class alone, which is supported and
  # invisible to a profile. So a missing property is a warning, never an error -- unlike
  # Hyrax's own redirects validator, which owns its feature and can insist.
  describe 'when the profile has no doi property' do
    let(:profile) { { 'classes' => { 'Monograph' => {} }, 'properties' => {} } }

    it 'warns without erroring' do
      validator.validate!
      expect(errors).to be_empty
      expect(warnings.join).to match(/doi/i)
    end
  end

  describe 'when the profile declares doi correctly' do
    let(:profile) { profile_with_doi }

    it 'passes silently' do
      validator.validate!
      expect(errors).to be_empty
      expect(warnings).to be_empty
    end
  end

  # Under flex, M3SchemaLoader#view_definitions_for drops any property whose view
  # options are empty, so a doi with no view block never renders on the show page.
  describe 'when doi has no view block' do
    let(:profile) do
      profile_with_doi.tap { |p| p['properties']['doi'].delete('view') }
    end

    it 'warns that it will not render on the show page' do
      validator.validate!
      expect(errors).to be_empty
      expect(warnings.join).to match(/view|show page/i)
    end
  end

  describe 'when doi is available_on no class in this profile' do
    let(:profile) do
      profile_with_doi.tap { |p| p['properties']['doi']['available_on'] = { 'class' => ['NotInProfile'] } }
    end

    it 'warns that the property is unreachable' do
      validator.validate!
      expect(warnings.join).to match(/available_on/i)
    end
  end

  describe 'with a nil profile' do
    let(:profile) { nil }

    it 'does not raise' do
      expect { validator.validate! }.not_to raise_error
    end
  end
end
