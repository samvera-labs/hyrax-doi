# frozen_string_literal: true
RSpec.shared_examples "a DOI-enabled form" do
  subject { form }

  it { is_expected.to delegate_method(:doi).to(:model) }

  it 'keeps the field out of the generic term lists' do
    expect(subject.primary_terms).not_to include(:doi)
    expect(subject.secondary_terms).not_to include(:doi)
  end
end
