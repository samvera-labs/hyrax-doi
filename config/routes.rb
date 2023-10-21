# frozen_string_literal: true
Hyrax::DOI::Engine.routes.draw do
  get '/create_draft_doi', controller: 'hyrax_doi', action: 'create_draft_doi', as: 'create_draft_doi'
end
