# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'hyrax/base/_form_doi', type: :view do
  let(:work) { Struct.new(:doi, :doi_status_when_public, :doi_state, keyword_init: true) }
  let(:model) { work.new(doi: [], doi_status_when_public: nil, doi_state: nil) }
  let(:form) { Hyrax::DOI::FormDouble.new(model) }
  # SimpleForm's builder, not Rails': the partial calls f.input, which only it provides.
  let(:builder) { SimpleForm::FormBuilder.new('monograph', form, view, {}) }

  before do
    stub_const('Hyrax::DOI::FormDouble', Class.new(SimpleDelegator) do
      def model = __getobj__
      def model_name = ActiveModel::Name.new(nil, nil, 'Monograph')
      def model_class = self.class
      def self.human_attribute_name(field) = field.to_s.titleize
      def to_model = self
      def persisted? = false
    end)

    allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(true)
    view.extend(Hyrax::DOI::WorkFormHelper)
  end

  it 'offers the draft button when no DOI exists yet' do
    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    expect(rendered).to have_selector('[data-doi-draft-button]')
  end

  it 'withholds the draft button once the work has a DOI' do
    model.doi = ['10.5072/abc']

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    expect(rendered).to have_no_selector('[data-doi-draft-button]')
  end

  it 'renders every intent, blank first' do
    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    values = Capybara.string(rendered)
                     .all('[data-doi-status-radio]')
                     .map { |radio| radio['value'] }
    expect(values).to eq ['', 'draft', 'registered', 'findable']
  end

  it 'closes off intents DataCite can no longer reach' do
    model.doi_state = 'findable'

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    page = Capybara.string(rendered)
    expect(page.find('#monograph_doi_status_when_public_none')).to be_disabled
    expect(page.find('#monograph_doi_status_when_public_draft')).to be_disabled
    expect(page.find('#monograph_doi_status_when_public_registered')).not_to be_disabled
  end

  it 'hides the minting controls when the feature is off' do
    allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(false)

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    expect(rendered).to have_no_selector('[data-doi-draft-button]')
    expect(rendered).to have_no_selector('[data-doi-status-radio]')
  end
end
