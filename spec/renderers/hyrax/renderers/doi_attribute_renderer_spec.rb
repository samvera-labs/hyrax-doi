# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Renderers::DOIAttributeRenderer do
  let(:values) { ['10.5072/abc123'] }

  def render(vals = values, options = {})
    Capybara.string(described_class.new(:doi, vals, options).render)
  end

  # The one example that catches a rename breaking the constant lookup.
  it 'is what Hyrax resolves render_as: doi to' do
    presenter = Class.new { include Hyrax::PresentsAttributes }.new

    expect(presenter.send(:find_renderer_class, :doi)).to eq described_class
  end

  it 'links the DOI to its resolver rather than showing a bare string' do
    expect(render).to have_link '10.5072/abc123', href: 'https://doi.org/10.5072/abc123'
  end

  # A DOI arriving from autofill may already carry the resolver prefix, and doubling it
  # would produce a link that does not resolve.
  it 'does not double a prefix that is already there' do
    expect(render(['https://doi.org/10.5072/abc123']))
      .to have_link '10.5072/abc123', href: 'https://doi.org/10.5072/abc123'
  end

  it 'renders nothing for a blank value' do
    expect(described_class.new(:doi, [], {}).render).to be_blank
  end

  describe 'draft suppression' do
    it 'withholds a draft DOI' do
      expect(described_class.new(:doi, values, doi_state: 'draft').render).to be_blank
    end

    # doi.yaml declares html_dl, so the show page takes this path rather than render.
    it 'withholds a draft DOI from the definition-list row too' do
      expect(described_class.new(:doi, values, doi_state: 'draft').render_dl_row).to be_blank
    end

    it 'shows a registered DOI' do
      expect(render(values, doi_state: 'registered')).to have_link '10.5072/abc123'
    end

    it 'shows a findable DOI' do
      expect(render(values, doi_state: 'findable')).to have_link '10.5072/abc123'
    end

    # An externally supplied DOI carries no state we track, and it resolves because
    # somebody else registered it.
    it 'shows a DOI whose state is unknown' do
      expect(render(values, doi_state: nil)).to have_link '10.5072/abc123'
    end
  end
end
