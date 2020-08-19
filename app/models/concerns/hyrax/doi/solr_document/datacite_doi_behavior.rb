# frozen_string_literal: true
module Hyrax
  module DOI
    module SolrDocument
      module DataCiteDOIBehavior
        extend ActiveSupport::Concern

        included do
          attribute :doi_status_when_public, ::SolrDocument::Solr::String, "doi_status_when_public_ssi"
        end
      end
    end
  end
end
