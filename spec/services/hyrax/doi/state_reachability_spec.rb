# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteRegistrar, '.state_unreachable?' do
  describe 'before anything is minted' do
    it 'allows every intent' do
      ['', 'draft', 'registered', 'findable'].each do |state|
        expect(described_class.state_unreachable?(state, from: nil)).to be false
      end
    end
  end

  describe 'once a draft exists' do
    it 'refuses only "do not mint"' do
      expect(described_class.state_unreachable?('', from: 'draft')).to be true
      expect(described_class.state_unreachable?('draft', from: 'draft')).to be false
      expect(described_class.state_unreachable?('findable', from: 'draft')).to be false
    end
  end

  describe 'once DataCite has registered the DOI' do
    it 'refuses both withdrawal and a return to draft' do
      expect(described_class.state_unreachable?('', from: 'registered')).to be true
      expect(described_class.state_unreachable?('draft', from: 'registered')).to be true
      expect(described_class.state_unreachable?('registered', from: 'registered')).to be false
      expect(described_class.state_unreachable?('findable', from: 'registered')).to be false
    end
  end

  describe 'once the DOI is findable' do
    it 'still allows registered, which DataCite reaches by hiding' do
      expect(described_class.state_unreachable?('registered', from: 'findable')).to be false
      expect(described_class.state_unreachable?('draft', from: 'findable')).to be true
    end
  end
end
