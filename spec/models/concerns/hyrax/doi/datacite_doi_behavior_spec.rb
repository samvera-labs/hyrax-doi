# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataCiteDOIBehavior do
  before do
    stub_const('DataCiteBehaviorTestWork', Class.new(Hyrax::Work) do
      def self.name = 'DataCiteBehaviorTestWork'
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end)
  end

  let(:work) { DataCiteBehaviorTestWork.new }

  it 'names datacite as its registrar' do
    expect(work.doi_registrar).to eq 'datacite'
  end

  it 'declares doi_status_when_public in both flex modes' do
    expect(work).to respond_to(:doi_status_when_public)
    work.doi_status_when_public = 'findable'
    expect(work.doi_status_when_public).to eq 'findable'
  end

  it 'defaults to blank, meaning do not mint' do
    expect(work.doi_status_when_public).to be_blank
  end

  # The work records intent only. What DataCite currently reports is on the
  # PersistentIdentifier record, so the two can legitimately disagree -- a work whose
  # intent is findable stays registered at DataCite while it is private.
  it 'is intent, separate from the state the provider reports' do
    work.doi_status_when_public = 'findable'
    pid = Hyrax::DOI::PersistentIdentifier.new(scheme: 'doi', provider: 'datacite',
                                               value: '10.5072/abc', origin: 'minted',
                                               state: 'registered')

    expect(work.doi_status_when_public).to eq 'findable'
    expect(pid.state).to eq 'registered'
  end

  it 'still carries doi from the base concern' do
    work.doi = ['10.5072/abc']
    expect(work.doi).to eq ['10.5072/abc']
  end
end
