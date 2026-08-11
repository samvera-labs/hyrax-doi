# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::RecordedIdentifier do
  describe '.for' do
    it 'resolves a registered scheme' do
      expect(described_class.for('orcid')).to be_a Hyrax::DOI::ORCIDIdentifier
      expect(described_class.for(:ror)).to be_a Hyrax::DOI::RORIdentifier
    end

    it 'returns nil for an unregistered scheme' do
      expect(described_class.for('isni')).to be_nil
    end
  end

  describe Hyrax::DOI::ORCIDIdentifier do
    subject(:scheme) { described_class.new }

    it { expect(scheme).to be_valid('0000-0002-1825-0097') }
    it { expect(scheme).to be_valid('0000-0002-1694-233X') }
    it { expect(scheme).not_to be_valid('0000-0002-1825') }
    it { expect(scheme).not_to be_valid('not-an-orcid') }
    it { expect(scheme).not_to be_valid(nil) }

    it 'accepts a pasted resolver URL' do
      expect(scheme).to be_valid('https://orcid.org/0000-0002-1825-0097')
    end

    it 'normalizes a resolver URL to the bare identifier' do
      expect(scheme.normalize('https://orcid.org/0000-0002-1825-0097')).to eq '0000-0002-1825-0097'
    end

    it 'builds a resolver url' do
      expect(scheme.resolve_url('0000-0002-1825-0097')).to eq 'https://orcid.org/0000-0002-1825-0097'
    end

    it 'returns nil resolving a blank value' do
      expect(scheme.resolve_url('')).to be_nil
    end
  end

  describe Hyrax::DOI::RORIdentifier do
    subject(:scheme) { described_class.new }

    it { expect(scheme).to be_valid('02mhbdp94') }
    it { expect(scheme).not_to be_valid('12mhbdp94') } # must start with 0
    it { expect(scheme).not_to be_valid('02mhbdp9') }

    it 'accepts a pasted resolver URL' do
      expect(scheme).to be_valid('https://ror.org/02mhbdp94')
    end

    it 'builds a resolver url' do
      expect(scheme.resolve_url('02mhbdp94')).to eq 'https://ror.org/02mhbdp94'
    end
  end
end
