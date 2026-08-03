# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::FlexibleProfileInstaller do
  # The profile Hyrax bootstraps with is loaded via `save(validate: false)` and does not
  # itself pass validation, so most of these assert on the merged profile the installer
  # builds rather than on a persisted row.
  let(:base_profile) do
    profile = YAML.safe_load(File.read(Hyrax::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')))
    profile['properties'].delete('doi')
    profile
  end

  describe '#merge_into' do
    subject(:merged) { described_class.new.merge_into(base_profile) }

    it 'adds both properties' do
      expect(merged['properties'].keys).to include('doi', 'doi_status_when_public')
    end

    it 'attaches them to every class the profile declares' do
      expect(merged.dig('properties', 'doi', 'available_on', 'class')).to eq base_profile['classes'].keys
    end

    it 'accepts an explicit class list' do
      merged = described_class.new(class_names: ['OnlyThis']).merge_into(base_profile)
      expect(merged.dig('properties', 'doi', 'available_on', 'class')).to eq ['OnlyThis']
    end

    # M3SchemaLoader#view_definitions_for drops properties whose view block is empty, so
    # without this the doi would never render on a show page.
    it 'gives doi a non-empty view block' do
      expect(merged.dig('properties', 'doi', 'view')).to include('render_as' => 'doi')
    end

    it 'indexes both properties' do
      expect(merged.dig('properties', 'doi', 'indexing')).to include('doi_ssim')
      expect(merged.dig('properties', 'doi_status_when_public', 'indexing')).to include('doi_status_when_public_ssi')
    end

    it 'keeps the properties the profile already had' do
      expect(merged['properties'].keys).to include(*base_profile['properties'].keys)
    end

    it 'does not mutate the profile it was given' do
      described_class.new.merge_into(base_profile)
      expect(base_profile.dig('properties', 'doi')).to be_nil
    end
  end

  describe '#call' do
    context 'with no existing profile' do
      before { allow(Hyrax::FlexibleSchema).to receive(:current_version).and_return(nil) }

      it 'reports rather than raising' do
        result = described_class.new.call
        expect(result).not_to be_created
        expect(result.message).to match(/no m3 profile/i)
      end
    end

    context 'when doi is already present' do
      before do
        profile = base_profile.deep_dup
        profile['properties']['doi'] = { 'available_on' => { 'class' => profile['classes'].keys } }
        allow(Hyrax::FlexibleSchema).to receive(:current_version).and_return(profile)
      end

      it 'does nothing' do
        expect { described_class.new.call }.not_to change(Hyrax::FlexibleSchema, :count)
      end

      it 'says so' do
        expect(described_class.new.call.message).to match(/already/i)
      end
    end

    # A profile's version is its row id, and saved works pin schema_version to it, so
    # editing the current row would retroactively change existing works' schema.
    context 'with a valid profile in the database' do
      let!(:existing) do
        schema = Hyrax::FlexibleSchema.new(profile: base_profile)
        schema.save(validate: false)
        schema
      end

      it 'creates a new version rather than editing the current one' do
        allow(Hyrax::FlexibleSchema).to receive(:current_version).and_return(base_profile)
        allow_any_instance_of(Hyrax::FlexibleSchema).to receive(:valid?).and_return(true)

        expect { described_class.new.call }.to change(Hyrax::FlexibleSchema, :count).by(1)
        expect(existing.reload.profile.dig('properties', 'doi')).to be_nil
      end
    end
  end
end
