# frozen_string_literal: true
require 'rails_helper'

# A repository may already hold DOIs somewhere other than `doi` -- in `identifier`, or
# in a field named for what it identifies rather than for the scheme. Since the
# PersistentIdentifier record is the source of truth, the work attribute is a
# projection, and where it projects is the host's choice.
RSpec.describe 'configuring which attribute holds the DOI' do
  describe 'the default' do
    before do
      stub_const('DefaultAttrWork', Class.new(Hyrax::Work) do
        def self.name = 'DefaultAttrWork'
        include Hyrax::DOI::DOIBehavior
      end)
    end

    it 'is :doi' do
      expect(DefaultAttrWork.doi_attribute).to eq :doi
      expect(DefaultAttrWork.new).to respond_to(:doi)
    end
  end

  describe 'overriding it' do
    before do
      stub_const('CustomAttrWork', Class.new(Hyrax::Work) do
        def self.name = 'CustomAttrWork'
        include Hyrax::DOI::DOIBehavior
        holds_doi_in :permalink
      end)
    end

    it 'declares the named attribute instead' do
      work = CustomAttrWork.new
      expect(CustomAttrWork.doi_attribute).to eq :permalink
      expect(work).to respond_to(:permalink)
    end

    it 'reads and writes through the configured attribute' do
      work = CustomAttrWork.new
      work.doi_value = ['10.5072/custom']

      expect(work.permalink).to eq ['10.5072/custom']
      expect(work.doi_value).to eq ['10.5072/custom']
    end
  end

  describe 'reading through the configured name' do
    before do
      stub_const('ReaderAttrWork', Class.new(Hyrax::Work) do
        def self.name = 'ReaderAttrWork'
        include Hyrax::DOI::DOIBehavior
      end)
    end

    it 'reads the default attribute without the host knowing the name' do
      work = ReaderAttrWork.new(doi: ['10.5072/default'])
      expect(work.doi_value).to eq ['10.5072/default']
    end

    it 'is empty when unset' do
      expect(ReaderAttrWork.new.doi_value).to eq []
    end

    # The host's own declaration wins on type, so the value may be a bare string
    # rather than an array. Callers must not assume.
    it 'normalizes a single-valued attribute to an array' do
      stub_const('SingleAttrWork', Class.new(Hyrax::Work) do
        def self.name = 'SingleAttrWork'
        attribute :doi, Valkyrie::Types::String
        include Hyrax::DOI::DOIBehavior
      end)

      expect(SingleAttrWork.new(doi: '10.5072/single').doi_value).to eq ['10.5072/single']
    end
  end
end
