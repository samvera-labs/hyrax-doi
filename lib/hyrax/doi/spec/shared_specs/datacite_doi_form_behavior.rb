# frozen_string_literal: true
RSpec.shared_examples "a DataCite DOI-enabled form" do
  subject { form }

  it 'reads the minting intent its work holds' do
    work = form.model
    work.doi_status_when_public = 'findable'

    expect(form.class.new(work).doi_status_when_public).to eq 'findable'
  end

  it 'accepts an intent and writes it back to the work' do
    form.validate('doi_status_when_public' => 'registered')
    form.sync

    expect(form.model.doi_status_when_public).to eq 'registered'
  end

  it 'keeps the field out of the generic term lists' do
    expect(subject.primary_terms).not_to include(:doi_status_when_public)
    expect(subject.secondary_terms).not_to include(:doi_status_when_public)
  end
end
