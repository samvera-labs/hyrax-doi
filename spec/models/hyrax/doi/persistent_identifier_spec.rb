# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::PersistentIdentifier do
  subject(:pid) do
    described_class.new(scheme: 'doi', provider: 'datacite', value: '10.5072/abc-123', origin: 'minted')
  end

  it 'is valid with the required attributes' do
    expect(pid).to be_valid
  end

  %i[scheme provider value origin].each do |attribute|
    it "requires #{attribute}" do
      pid.public_send("#{attribute}=", nil)
      expect(pid).not_to be_valid
    end
  end

  it 'rejects an unknown origin' do
    pid.origin = 'borrowed'
    expect(pid).not_to be_valid
  end

  it 'may exist before the resource it will belong to' do
    expect(pid.resource_id).to be_nil
    expect(pid).to be_valid
  end

  describe 'uniqueness' do
    before { pid.save! }

    it 'rejects the same value for the same scheme and provider' do
      duplicate = described_class.new(scheme: 'doi', provider: 'datacite',
                                      value: '10.5072/abc-123', origin: 'minted')
      expect(duplicate).not_to be_valid
    end

    it 'allows the same value under a different scheme' do
      other = described_class.new(scheme: 'igsn', provider: 'datacite',
                                  value: '10.5072/abc-123', origin: 'minted')
      expect(other).to be_valid
    end
  end

  describe 'holding several identifiers for one resource' do
    let(:resource_id) { 'abc123' }

    it 'does not overwrite one scheme with another' do
      doi = described_class.create!(resource_id:, scheme: 'doi', provider: 'datacite',
                                    value: '10.5072/xyz', origin: 'minted')
      raid = described_class.create!(resource_id:, scheme: 'raid', provider: 'datacite',
                                     value: '10.5072/raid-1', origin: 'minted')

      expect(described_class.for_resource(resource_id)).to contain_exactly(doi, raid)
      expect(described_class.primary_for(resource_id:, scheme: 'doi')).to eq doi
      expect(described_class.primary_for(resource_id:, scheme: 'raid')).to eq raid
    end
  end

  describe '#minted? and #external?' do
    it 'distinguishes identifiers we created from ones supplied to us' do
      expect(pid).to be_minted
      expect(pid).not_to be_external

      pid.origin = 'external'
      expect(pid).to be_external
      expect(pid).not_to be_minted
    end
  end

  describe '#record_sync' do
    before { pid.save! }

    it 'records a successful sync' do
      pid.record_sync(state: 'findable')
      expect(pid.reload).to have_attributes(state: 'findable', last_error: nil)
      expect(pid.last_synced_at).to be_present
    end

    it 'records a failure without advancing last_synced_at' do
      pid.record_sync(error: 'DataCite returned 422')
      expect(pid.reload.last_error).to eq 'DataCite returned 422'
      expect(pid.last_synced_at).to be_nil
    end

    it 'clears a previous error on the next success' do
      pid.record_sync(error: 'transient failure')
      pid.record_sync(state: 'registered')
      expect(pid.reload.last_error).to be_nil
    end
  end
end
