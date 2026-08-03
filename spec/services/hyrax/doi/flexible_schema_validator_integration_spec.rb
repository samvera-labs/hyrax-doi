# frozen_string_literal: true
require 'rails_helper'

# The validator is only useful if it actually runs as part of Hyrax's validation, which
# depends on the engine's prepend having taken effect.
RSpec.describe 'DOI validation within Hyrax::FlexibleSchemaValidatorService' do
  it 'prepends the decorator' do
    expect(Hyrax::FlexibleSchemaValidatorService.ancestors)
      .to include(Hyrax::DOI::FlexibleSchemaValidatorServiceDecorator)
  end

  it 'warns about a missing doi property while validating a profile' do
    profile = YAML.safe_load(File.read(Hyrax::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')))
    service = Hyrax::FlexibleSchemaValidatorService.new(profile: profile)

    service.validate!

    expect(service.warnings.join).to match(/doi/i)
  end
end
