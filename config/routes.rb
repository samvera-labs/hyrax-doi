# frozen_string_literal: true
Hyrax::DOI::Engine.routes.draw do
  # POST, not GET: both reserve a real identifier at DataCite, so neither may be reachable
  # by a speculative request from a browser or a link prefetcher.
  post '/create_draft_doi', controller: 'hyrax_doi', action: 'create_draft_doi', as: 'create_draft_doi'
  post '/works/:id/mint', controller: 'hyrax_doi', action: 'mint', as: 'mint'

  get '/autofill', controller: 'hyrax_doi', action: 'autofill', as: 'autofill'
end
