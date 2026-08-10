# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'recording a DOI from the deposit form' do
  let(:form_class) do
    Class.new(Hyrax::Forms::ResourceForm(DOIWork)) do
      include Hyrax::DOI::DOIFormBehavior
      include Hyrax::DOI::DataCiteDOIFormBehavior
    end
  end
  let(:work) { DOIWork.new(title: ['Moomin']) }
  let(:form) { form_class.new(work) }

  describe 'the DOI a depositor typed' do
    it 'reaches the form' do
      form.validate('doi' => ['10.5072/typed'], 'doi_status_when_public' => '')

      expect(Array(form.doi)).to eq ['10.5072/typed']
    end

    it 'reaches the work when the form is applied' do
      form.validate('doi' => ['10.5072/typed'], 'doi_status_when_public' => '')
      form.sync

      expect(Array(work.doi)).to eq ['10.5072/typed']
    end
  end

  describe 'the minting intent a depositor chose' do
    it 'reaches the form' do
      form.validate('doi' => [''], 'doi_status_when_public' => 'findable')

      expect(form.doi_status_when_public).to eq 'findable'
    end

    it 'reaches the work when the form is applied' do
      form.validate('doi' => [''], 'doi_status_when_public' => 'findable')
      form.sync

      expect(work.doi_status_when_public).to eq 'findable'
    end
  end

  # A hidden panel still submits its inputs, so the mode radio is what says which of them
  # the depositor meant.
  describe 'reconciling the choice with what the hidden panels submitted' do
    it 'keeps a typed DOI when recording one the work already has' do
      form.validate('doi_mode' => 'existing',
                    'doi' => ['10.5072/published-elsewhere'],
                    'doi_status_when_public' => 'findable')

      expect(Array(form.doi)).to eq ['10.5072/published-elsewhere']
      expect(form.doi_status_when_public).to be_blank
    end

    it 'keeps a reserved DOI whatever mode was submitted' do
      form.validate('doi_mode' => 'mint',
                    'doi_reserved' => '10.5072/reserved-just-now',
                    'doi_status_when_public' => 'draft')

      expect(Array(form.doi)).to eq ['10.5072/reserved-just-now']
      expect(form.doi_status_when_public).to eq 'draft'
    end

    it 'keeps a reserved DOI even when the depositor then chose to mint nothing' do
      form.validate('doi_mode' => 'none', 'doi_reserved' => '10.5072/reserved-then-changed')

      expect(Array(form.doi)).to eq ['10.5072/reserved-then-changed']
    end

    it 'discards a typed DOI when minting a new one instead' do
      form.validate('doi_mode' => 'mint',
                    'doi' => ['10.5072/leftover'],
                    'doi_status_when_public' => 'findable')

      expect(Array(form.doi).compact_blank).to be_empty
      expect(form.doi_status_when_public).to eq 'findable'
    end

    it 'discards both when the depositor wants no DOI' do
      form.validate('doi_mode' => 'none',
                    'doi' => ['10.5072/leftover'],
                    'doi_status_when_public' => 'findable')

      expect(Array(form.doi).compact_blank).to be_empty
      expect(form.doi_status_when_public).to be_blank
    end

    # Absent from the wizard, which renders the fields without the mode radios.
    it 'takes the submitted values at face value when no mode was sent' do
      form.validate('doi' => ['10.5072/no-mode'], 'doi_status_when_public' => '')

      expect(Array(form.doi)).to eq ['10.5072/no-mode']
    end

    # What a controller actually passes. Unpermitted ActionController::Parameters raise on
    # to_h, so reconciling has to work on them without demanding they be permitted first.
    it 'reconciles what a controller submits, not only a plain hash' do
      params = ActionController::Parameters.new(doi_mode: 'none',
                                                doi: ['10.5072/leftover'],
                                                doi_status_when_public: 'findable')

      expect { form.validate(params) }.not_to raise_error
      expect(Array(form.doi).compact_blank).to be_empty
    end

    it 'keeps an existing-mode DOI submitted as controller parameters' do
      params = ActionController::Parameters.new(doi_mode: 'existing',
                                                doi: ['10.5072/from-controller'])

      form.validate(params)

      expect(Array(form.doi)).to eq ['10.5072/from-controller']
    end
  end

  describe 'a work whose DOI is already recorded' do
    let(:work) { DOIWork.new(title: ['Moomin'], doi: ['10.5072/already-here']) }

    it 'does not lose that DOI to a mint choice' do
      form.validate('doi_mode' => 'mint', 'doi_status_when_public' => 'findable')

      expect(Array(form.doi)).to eq ['10.5072/already-here']
    end
  end
end
