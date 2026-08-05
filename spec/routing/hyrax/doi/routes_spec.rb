# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'DOI routes' do
  routes { Hyrax::DOI::Engine.routes }

  it 'reserves a draft DOI by POST only' do
    expect(post: '/create_draft_doi').to be_routable
    expect(get: '/create_draft_doi').not_to be_routable
  end

  it 'mints for a work by POST only' do
    expect(post: '/works/abc/mint').to be_routable
    expect(get: '/works/abc/mint').not_to be_routable
  end

  it 'reads a DOI for autofill by GET, which changes nothing' do
    expect(get: '/autofill').to be_routable
  end
end
