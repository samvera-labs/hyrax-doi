# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::RegistrationResult do
  it 'carries an identifier and provider state' do
    result = described_class.new(identifier: '10.5072/abc', state: 'findable', changed: true)

    expect(result).to be_success
    expect(result).to be_changed
    expect(result.identifier).to eq '10.5072/abc'
    expect(result.state).to eq 'findable'
  end

  it 'distinguishes a skip from a failure' do
    skipped = described_class.new(identifier: '10.5072/abc')

    expect(skipped).to be_success
    expect(skipped).not_to be_changed
    expect(skipped.error_message).to be_nil
  end

  it 'reports failures' do
    failed = described_class.new(errors: ['creators is required', 'publisher is required'])

    expect(failed).to be_failure
    expect(failed).not_to be_success
    expect(failed.error_message).to eq 'creators is required; publisher is required'
  end

  it 'stringifies to the identifier so it can stand in for one' do
    expect(described_class.new(identifier: '10.5072/abc').to_s).to eq '10.5072/abc'
  end

  it 'keeps the raw provider response for logging' do
    response = { 'errors' => [{ 'title' => 'boom' }] }
    expect(described_class.new(response: response).response).to eq response
  end
end
