# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DOIResolver do
  subject(:resolver) { described_class.new }

  def stub_csl(doi, fixture)
    stub_request(:get, "https://doi.org/#{doi}")
      .with(headers: { 'Accept' => 'application/vnd.citationstyles.csl+json' })
      .to_return(status: 200,
                 body: File.read(Hyrax::DOI::Engine.root.join('spec', 'fixtures', 'csl', fixture)),
                 headers: { 'Content-Type' => 'application/vnd.citationstyles.csl+json' })
  end

  describe 'a CrossRef DOI' do
    let(:attributes) { resolver.attributes_for('10.1038/nature12373') }

    before { stub_csl('10.1038/nature12373', 'crossref_journal_article.json') }

    it 'reads the title' do
      expect(attributes[:title]).to eq ['Nanometre-scale thermometry in a living cell']
    end

    it 'builds creators family-first, the order a name authority expects' do
      expect(attributes[:creator]).to eq ['Kucsko, G.', 'Maurer, P. C.']
    end

    it 'reads the publisher' do
      expect(attributes[:publisher]).to eq ['Springer Science and Business Media LLC']
    end

    it 'formats a full date' do
      expect(attributes[:date_created]).to eq ['2013-07-31']
    end
  end

  describe 'a DataCite DOI' do
    let(:attributes) { resolver.attributes_for('10.5061/dryad.8515') }

    before { stub_csl('10.5061/dryad.8515', 'datacite_dataset.json') }

    it 'reads the title' do
      expect(attributes[:title]).to eq ['Data from: A new malaria agent in African hominids.']
    end

    it 'reads the abstract as description' do
      expect(attributes[:description].first).to start_with 'Plasmodium falciparum is the major'
    end

    it 'reads keywords from categories' do
      expect(attributes[:keyword]).to include 'Malaria', 'Parasites'
    end

    it 'formats a full date' do
      expect(attributes[:date_created]).to eq ['2011-02-01']
    end
  end

  describe 'partial dates' do
    it 'keeps a year-month as year-month rather than inventing a day' do
      stub_request(:get, 'https://doi.org/10.1234/ym')
        .to_return(status: 200, body: { 'issued' => { 'date-parts' => [[2019, 3]] } }.to_json)

      expect(resolver.attributes_for('10.1234/ym')[:date_created]).to eq ['2019-03']
    end

    it 'keeps a year alone as a year' do
      stub_request(:get, 'https://doi.org/10.1234/y')
        .to_return(status: 200, body: { 'issued' => { 'date-parts' => [[2019]] } }.to_json)

      expect(resolver.attributes_for('10.1234/y')[:date_created]).to eq ['2019']
    end
  end

  describe 'failure' do
    it 'raises NotFoundError for an unknown DOI' do
      stub_request(:get, 'https://doi.org/10.1234/nope').to_return(status: 404)

      expect { resolver.attributes_for('10.1234/nope') }
        .to raise_error(Hyrax::DOI::NotFoundError, /10\.1234\/nope/)
    end

    it 'raises NotFoundError when the response is not JSON at all' do
      stub_request(:get, 'https://doi.org/10.1234/html').to_return(status: 200, body: '<html>')

      expect { resolver.attributes_for('10.1234/html') }.to raise_error(Hyrax::DOI::NotFoundError)
    end

    # Valid JSON that is not a CSL record: parses cleanly, so only the shape check stops it.
    it 'raises NotFoundError for JSON that is not a CSL object' do
      stub_request(:get, 'https://doi.org/10.1234/array').to_return(status: 200, body: '[1,2]')

      expect { resolver.attributes_for('10.1234/array') }.to raise_error(Hyrax::DOI::NotFoundError)
    end

    it 'reports a resolver outage separately from a missing DOI' do
      stub_request(:get, 'https://doi.org/10.1234/down').to_return(status: 503)

      expect { resolver.attributes_for('10.1234/down') }
        .to raise_error(Hyrax::DOI::Error, /doi\.org/)
    end
  end
end
