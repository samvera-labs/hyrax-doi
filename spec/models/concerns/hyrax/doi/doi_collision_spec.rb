# frozen_string_literal: true
require 'rails_helper'

# What happens when a host has already declared `doi` -- via a metadata profile under
# flex, or a YAML schema without it -- and then includes the concern? Redeclaring an
# attribute must not raise or silently drop data, or the gem is unusable in any
# repository that already had a DOI field.
RSpec.describe 'declaring doi when the host already has it' do
  it 'tolerates the attribute being declared twice' do
    expect do
      stub_const('PredeclaredDOIWork', Class.new(Hyrax::Work) do
        def self.name = 'PredeclaredDOIWork'
        attribute :doi, Valkyrie::Types::Array.of(Valkyrie::Types::String)
        include Hyrax::DOI::DOIBehavior
      end)
    end.not_to raise_error

    work = PredeclaredDOIWork.new(doi: ['10.5072/pre-existing'])
    expect(work.doi).to eq ['10.5072/pre-existing']
  end

  it 'tolerates the concern being included twice' do
    expect do
      stub_const('DoubleIncludeWork', Class.new(Hyrax::Work) do
        def self.name = 'DoubleIncludeWork'
        include Hyrax::DOI::DOIBehavior
        include Hyrax::DOI::DOIBehavior
      end)
    end.not_to raise_error
  end

  # The host's declaration wins. A repository that already models doi as single-valued
  # keeps that type rather than having the gem silently widen it.
  it 'leaves an existing declaration alone' do
    stub_const('SingleValuedDOIWork', Class.new(Hyrax::Work) do
      def self.name = 'SingleValuedDOIWork'
      attribute :doi, Valkyrie::Types::String
      include Hyrax::DOI::DOIBehavior
    end)

    work = SingleValuedDOIWork.new(doi: '10.5072/abc')
    expect(work.doi).to eq '10.5072/abc'
  end

  # sync_doi_projection! always writes an array. Valkyrie::Types::String quietly accepts
  # one, but Strict::String raises Dry::Types::ConstraintError, which would fail every sync
  # for a repository that declared its DOI field that way.
  it 'writes a single value to an attribute that will not take an array' do
    stub_const('StrictDOIWork', Class.new(Hyrax::Work) do
      def self.name = 'StrictDOIWork'
      attribute :doi, Valkyrie::Types::Strict::String
      include Hyrax::DOI::DOIBehavior
    end)

    work = StrictDOIWork.new
    expect { work.doi_value = ['10.5072/abc'] }.not_to raise_error
    expect(work.doi).to eq '10.5072/abc'
    expect(work.doi_value).to eq ['10.5072/abc']
  end

  it 'tolerates doi_status_when_public being predeclared' do
    expect do
      stub_const('PredeclaredStatusWork', Class.new(Hyrax::Work) do
        def self.name = 'PredeclaredStatusWork'
        attribute :doi_status_when_public, Valkyrie::Types::String
        include Hyrax::DOI::DOIBehavior
        include Hyrax::DOI::DataCiteDOIBehavior
      end)
    end.not_to raise_error
  end
end
