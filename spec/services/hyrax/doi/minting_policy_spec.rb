# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::MintingPolicy do
  before do
    stub_const('PolicyWork', Class.new(Hyrax::Work) do
      def self.name = 'PolicyWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end)
    stub_const('PlainWork', Class.new(Hyrax::Work) do
      def self.name = 'PlainWork'
    end)
  end

  subject(:policy) { described_class.new }

  let(:work) { PolicyWork.new(doi_status_when_public: 'draft') }

  after { Hyrax::DOI.reset_config! }

  describe '#mintable?' do
    it 'is true for a DOI-enabled work whose depositor asked for a DOI' do
      expect(policy).to be_mintable(work)
    end

    it 'is false when the depositor asked for none' do
      expect(policy).not_to be_mintable(PolicyWork.new)
    end

    it 'is false for a work type without the DOI concern' do
      expect(policy).not_to be_mintable(PlainWork.new)
    end

    it 'is false for a work type that has the attribute but no registrar' do
      stub_const('AttributeOnlyWork', Class.new(Hyrax::Work) do
        def self.name = 'AttributeOnlyWork'
        attribute :doi_status_when_public, Valkyrie::Types::String
      end)

      expect(policy).not_to be_mintable(AttributeOnlyWork.new(doi_status_when_public: 'draft'))
    end

    it 'is false when DOI minting is switched off' do
      allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(false)
      expect(policy).not_to be_mintable(work)
    end
  end

  describe 'limiting eligible work types' do
    it 'accepts a work type on the list' do
      policy = described_class.new(work_types: ['PolicyWork'])
      expect(policy).to be_mintable(work)
    end

    it 'rejects a work type off the list' do
      policy = described_class.new(work_types: ['SomethingElse'])
      expect(policy).not_to be_mintable(work)
    end

    it 'accepts every DOI-enabled type when no list is given' do
      expect(described_class.new.work_types).to be_nil
    end
  end

  describe '#default_state' do
    it 'is draft, so nothing is published without being asked for' do
      expect(policy.default_state).to eq 'draft'
    end

    it 'can be set for a repository that wants findable by default' do
      expect(described_class.new(default_state: 'findable').default_state).to eq 'findable'
    end

    it 'refuses a state DataCite does not have' do
      expect { described_class.new(default_state: 'nonsense') }
        .to raise_error(ArgumentError, /nonsense/)
    end
  end

  describe 'the configured policy' do
    it 'defaults to a permissive one' do
      expect(Hyrax::DOI.config.minting_policy).to be_a described_class
    end

    it 'can be replaced wholesale' do
      custom = Class.new(described_class) do
        def mintable?(_work) = false
      end
      Hyrax::DOI.configure { |config| config.minting_policy = custom.new }

      expect(Hyrax::DOI.config.minting_policy).not_to be_mintable(work)
    end
  end

  describe 'the registrar consulting the policy' do
    let(:credentials) do
      Hyrax::DOI::Credentials.new(provider: 'datacite', prefix: '10.5072',
                                  username: 'u', password: 'p', mode: 'test')
    end

    it 'does not call DataCite for a work the policy excludes' do
      Hyrax::DOI.configure do |config|
        config.minting_policy = described_class.new(work_types: ['SomethingElse'])
      end
      work.doi = ['10.5072/abc']

      result = Hyrax::DOI::DataCiteRegistrar.new(credentials: credentials).register!(object: work)

      expect(result).not_to be_changed
      expect(a_request(:any, /api\.test\.datacite\.org/)).not_to have_been_made
    end
  end
end
