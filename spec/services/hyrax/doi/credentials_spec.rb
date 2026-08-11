# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::Credentials do
  subject(:credentials) do
    described_class.new(provider: 'datacite', prefix: '10.5072',
                        username: 'REPO.TEST', password: 'secret', mode: 'test')
  end

  it 'exposes the provider fields' do
    expect(credentials).to have_attributes(provider: 'datacite', prefix: '10.5072',
                                           username: 'REPO.TEST', password: 'secret')
  end

  describe '#mode' do
    it 'symbolizes whatever the store gave us' do
      expect(credentials.mode).to eq :test
    end

    it 'defaults to test rather than production' do
      expect(described_class.new(provider: 'datacite').mode).to eq :test
    end

    it 'accepts production' do
      expect(described_class.new(provider: 'datacite', mode: 'production').mode).to eq :production
    end
  end

  describe '#complete?' do
    it 'is true when a provider can actually be called' do
      expect(credentials).to be_complete
    end

    %i[prefix username password].each do |field|
      it "is false without #{field}" do
        expect(credentials.with(field => nil)).not_to be_complete
      end
    end
  end

  # Credentials must never reach a log, an exception report, or a job payload.
  describe 'redaction' do
    it 'omits the password from inspect' do
      expect(credentials.inspect).not_to include 'secret'
    end

    it 'omits the password from to_s' do
      expect(credentials.to_s).not_to include 'secret'
    end

    it 'still shows the non-secret fields' do
      expect(credentials.inspect).to include '10.5072'
    end
  end
end
