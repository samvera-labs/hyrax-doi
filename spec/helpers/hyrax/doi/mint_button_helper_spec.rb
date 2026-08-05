# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::MintButtonHelper do
  subject(:helper_object) { Class.new { include Hyrax::DOI::MintButtonHelper }.new }

  # A plain double: can? comes from CanCan's included module, so instance_double cannot
  # verify it.
  let(:ability) { double('ability') } # rubocop:disable RSpec/VerifiedDoubles

  let(:presenter) do
    PolicyPresenter.new(doi: nil, doi_status_when_public: 'findable',
                        model: PolicyPresenterWork)
  end

  before do
    stub_const('PolicyPresenterWork', Class.new(Hyrax::Work) do
      def self.name = 'PolicyPresenterWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end)

    stub_const('PolicyPresenter', Struct.new(:doi, :doi_status_when_public, :model,
                                             keyword_init: true))

    allow(ability).to receive(:can?).with(:edit, anything).and_return(true)
  end

  after { Hyrax::DOI.reset_config! }

  it 'offers minting for an editable work with no DOI' do
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be true
  end

  it 'does not offer minting for a work that already has one' do
    allow(presenter).to receive(:doi).and_return(['10.5072/abc'])
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be false
  end

  it 'does not offer minting to a user who cannot edit' do
    allow(ability).to receive(:can?).with(:edit, presenter).and_return(false)
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be false
  end

  it 'does not offer minting when the feature is switched off' do
    allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(false)
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be false
  end

  it 'does not offer minting when the depositor asked for no DOI' do
    allow(presenter).to receive(:doi_status_when_public).and_return(nil)
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be false
  end

  it 'does not offer minting for a work type the policy excludes' do
    Hyrax::DOI.configure do |config|
      config.minting_policy = Hyrax::DOI::MintingPolicy.new(work_types: ['SomethingElse'])
    end
    expect(helper_object.show_mint_doi_button?(presenter, ability: ability)).to be false
  end

  it 'does not offer minting for a presenter with no DOI support at all' do
    plain = instance_double(Hyrax::WorkShowPresenter)
    expect(helper_object.show_mint_doi_button?(plain, ability: ability)).to be false
  end

  describe '#show_actions_for' do
    subject(:contributor) do
      Class.new do
        def show_actions_for(presenter:) # rubocop:disable Lint/UnusedMethodArgument
          ['someone_elses_action']
        end
        prepend Hyrax::DOI::MintButtonHelper
      end.new
    end

    it 'adds its action without displacing another engine\'s' do
      expect(contributor.show_actions_for(presenter: presenter))
        .to eq %w[someone_elses_action mint_doi]
    end
  end
end
