# frozen_string_literal: true
require 'rails_helper'

describe 'Hyrax::DOI' do
  it 'has a version' do
    expect(Hyrax::DOI::VERSION).not_to be_nil
  end
end
