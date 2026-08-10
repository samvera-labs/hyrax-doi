# frozen_string_literal: true
RSpec.shared_examples "a DOI-enabled form" do
  subject { form }

  # Built after the work has its DOI, the way a form is built on an edit page: Reform reads
  # a property's value once, at construction.
  it 'reads the DOI its work holds' do
    work = form.model
    work.doi_value = ['10.5072/shared-example']

    expect(Array(form.class.new(work).doi)).to eq ['10.5072/shared-example']
  end

  it 'accepts a DOI and writes it back to the work' do
    form.validate('doi' => ['10.5072/submitted'])
    form.sync

    expect(Array(form.model.doi_value)).to eq ['10.5072/submitted']
  end

  it 'returns the resource from sync' do
    form.validate('doi' => ['10.5072/submitted'])

    expect(form.sync).to be_a Valkyrie::Resource
  end

  it 'keeps the field out of the generic term lists' do
    expect(subject.primary_terms).not_to include(:doi)
    expect(subject.secondary_terms).not_to include(:doi)
  end
end
