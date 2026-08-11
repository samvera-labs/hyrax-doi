# frozen_string_literal: true
module Hyrax
  module DOI
    module SolrDocument
      module DOIBehavior
        extend ActiveSupport::Concern

        included do
          # Keys must match what the indexer and config/metadata/doi.yaml write.
          attribute :doi, ::SolrDocument::Solr::Array, 'doi_ssim'

          # What the provider last reported, as distinct from the depositor's intent.
          attribute :doi_state, ::SolrDocument::Solr::String, 'doi_state_ssi'
        end
      end
    end
  end
end
