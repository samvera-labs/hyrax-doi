# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DOIBehavior do
  before do
    stub_const('DOIBehaviorTestWork', Class.new(Hyrax::Work) do
      def self.name = 'DOIBehaviorTestWork'
      include Hyrax::DOI::DOIBehavior
    end)
  end

  let(:work) { DOIBehaviorTestWork.new }

  # The concern declares a class-level Valkyrie attribute rather than contributing to
  # a metadata profile, because Hyrax::Flexibility layers the profile schema on top of
  # the class schema. Under flex it is the singleton that gains the profile's
  # attributes, so the class-level declaration survives either way.
  it 'declares doi in both flex modes' do
    expect(work).to respond_to(:doi)
    work.doi = ['10.5072/abc-123']
    expect(work.doi).to eq ['10.5072/abc-123']
  end

  it 'holds multiple values' do
    work.doi = ['10.5072/a', '10.5072/b']
    expect(work.doi).to contain_exactly('10.5072/a', '10.5072/b')
  end

  describe 'DOI_REGEX' do
    subject(:regex) { described_class::DOI_REGEX }

    it { is_expected.to match '10.5072/abc-123' }
    it { is_expected.to match '10.18130/v3-k4an-w022' }
    it { is_expected.not_to match 'https://doi.org/10.5072/abc' }
    it { is_expected.not_to match 'not-a-doi' }
    it { is_expected.not_to match '10.5072' }
  end

  describe '#doi_registrar' do
    it 'is nil until a scheme-specific concern sets one' do
      expect(work.doi_registrar).to be_nil
      expect(work.doi_registrar_opts).to eq({})
    end
  end
end
