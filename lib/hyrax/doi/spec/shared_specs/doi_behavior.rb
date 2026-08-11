# frozen_string_literal: true

# Include this in an application's own spec for a work type that mints DOIs, to check the
# type is wired the way the registrar expects:
#
#   RSpec.describe Monograph do
#     let(:work) { described_class.new }
#     it_behaves_like 'a DOI-enabled model'
#   end
RSpec.shared_examples "a DOI-enabled model" do
  subject { work }

  it 'carries a doi attribute' do
    expect(subject).to respond_to(:doi)
  end

  it 'reads its DOI through doi_value regardless of which attribute holds it' do
    expect(subject.doi_value).to be_an(Array)
  end

  # Naming a registrar is what makes a work type mintable -- the minting policy treats a
  # work with none as ineligible, whatever its metadata says.
  it 'names a registrar, or none' do
    expect(subject.doi_registrar).to be_a(String).or be_nil
  end

  it 'offers registrar options as a hash' do
    expect(subject.doi_registrar_opts).to be_a Hash
  end
end
