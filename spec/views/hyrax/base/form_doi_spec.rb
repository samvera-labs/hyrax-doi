# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'hyrax/base/_form_doi', type: :view do
  let(:work) { Struct.new(:doi, :doi_status_when_public, :doi_state, keyword_init: true) }
  let(:model) { work.new(doi: [], doi_status_when_public: nil, doi_state: nil) }
  let(:form) { Hyrax::DOI::FormDouble.new(model) }
  let(:builder) { SimpleForm::FormBuilder.new('monograph', form, view, {}) }

  before do
    stub_const('Hyrax::DOI::FormDouble', Class.new(SimpleDelegator) do
      def model = __getobj__
      def model_name = ActiveModel::Name.new(nil, nil, 'Monograph')
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

  describe 'a reserved DOI' do
    it 'has somewhere of its own to appear, beside the button' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      reserved = Capybara.string(rendered).find('[data-doi-reserved]', visible: :all)
      expect(reserved).to have_selector('[data-doi-reserved-input]', visible: :all)
      expect(reserved.find(:xpath, 'ancestor::*[@class="doi-reserve"]')).to be_present
    end

    it 'stays hidden until one is reserved' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(rendered).to have_no_selector('[data-doi-reserved]')
      expect(rendered).to have_selector('[data-doi-reserved]', visible: :hidden)
    end

    it 'offers a copy button, since the DOI is reserved in order to be pasted elsewhere' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(rendered).to have_selector('[data-doi-copy-button]', visible: :all)
    end

    it 'submits as the work-s DOI, so saving keeps it' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      field = Capybara.string(rendered).find('[data-doi-reserved-input]', visible: :all)
      expect(field['name']).to eq 'monograph[doi][]'
    end
  end

  describe 'choosing what to do about a DOI' do
    it 'offers the three situations as one choice' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      values = Capybara.string(rendered).all('.doi-mode__radio', visible: :all).map { |r| r['value'] }
      expect(values).to eq %w[none existing mint]
    end

    it 'preselects doing nothing' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      checked = Capybara.string(rendered)
                        .all('.doi-mode__radio', visible: :all)
                        .select { |r| r['checked'] }
                        .map { |r| r['value'] }
      expect(checked).to eq ['none']
    end

    it 'selects the minting mode for a work whose status is already chosen' do
      model.doi_status_when_public = 'findable'

      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      checked = Capybara.string(rendered)
                        .all('.doi-mode__radio', visible: :all)
                        .select { |r| r['checked'] }
                        .map { |r| r['value'] }
      expect(checked).to eq ['mint']
    end

    it 'selects the existing-DOI mode for a work that has one but no status' do
      model.doi = ['10.5072/abc']

      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      checked = Capybara.string(rendered)
                        .all('.doi-mode__radio', visible: :all)
                        .select { |r| r['checked'] }
                        .map { |r| r['value'] }
      expect(checked).to eq ['existing']
    end

    it 'clears the status unless a status radio is checked' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      hidden = Capybara.string(rendered)
                       .all("input[type='hidden'][name*='doi_status_when_public']", visible: :all)
      expect(hidden.map { |h| h['value'] }).to eq ['']
    end

    it 'says what each status does, and whether it can be undone' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(rendered).to have_text(/does not resolve yet/i)
      expect(rendered).to have_text(/resolves permanently/i)
      expect(rendered).to have_text(/reversible/i)
      expect(rendered).to have_text(/permanent/i)
    end

    # The stylesheet drives the disclosure, so the tab must not depend on the host having
    # required the gem's JavaScript.
    it 'brings its own stylesheet' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(rendered).to have_selector("link[href*='doi_form']", visible: :all)
    end
  end

  it 'withholds the draft button once the work has a DOI' do
    model.doi = ['10.5072/abc']

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    expect(rendered).to have_no_selector('[data-doi-draft-button]')
  end

  describe 'the autofill button' do
    it 'is offered even when a DOI is already present, since the work may be published elsewhere' do
      model.doi = ['10.5072/abc']

      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(rendered).to have_selector('[data-doi-autofill-button]')
    end

    it 'points at the path the host actually mounted' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      url = Capybara.string(rendered).find('[data-doi-autofill-button]')['data-doi-url']
      expect(url).to eq view.hyrax_doi.autofill_path
    end

    # The JS derives each field's wrapper selector from this, so a wrong param key would
    # silently fill nothing.
    it 'carries the param key the JS needs to find form fields' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(Capybara.string(rendered).find('[data-doi-autofill-button]')['data-doi-param-key'])
        .to eq 'monograph'
    end

    it 'carries a confirmation, since autofill overwrites what the depositor typed' do
      render partial: 'hyrax/base/form_doi', locals: { f: builder }

      expect(Capybara.string(rendered).find('[data-doi-autofill-button]')['data-doi-confirm'])
        .to be_present
    end
  end

  it 'offers the three states a DOI can be minted into' do
    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    values = Capybara.string(rendered)
                     .all('[data-doi-status-radio]', visible: :all)
                     .map { |radio| radio['value'] }
    expect(values).to eq %w[draft registered findable]
  end

  it 'closes off intents DataCite can no longer reach' do
    model.doi_state = 'findable'

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    page = Capybara.string(rendered)
    expect(page.find('#monograph_doi_status_when_public_draft', visible: :all)).to be_disabled
    expect(page.find('#monograph_doi_status_when_public_registered', visible: :all)).not_to be_disabled
  end

  it 'hides the minting controls when the feature is off' do
    allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(false)

    render partial: 'hyrax/base/form_doi', locals: { f: builder }

    expect(rendered).to have_no_selector('[data-doi-draft-button]')
    expect(rendered).to have_no_selector('[data-doi-status-radio]')
  end
end
