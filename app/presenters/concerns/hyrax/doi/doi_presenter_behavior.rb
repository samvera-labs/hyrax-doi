# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIPresenterBehavior
      extend ActiveSupport::Concern

      delegate :doi_state, to: :solr_document

      # Indexed multivalued because the Valkyrie attribute is, but a work has one DOI.
      def doi
        Array(solr_document.doi).first.presence
      end

      def doi_render_options
        { render_as: :doi, html_dl: true, doi_state: }
      end
    end
  end
end
