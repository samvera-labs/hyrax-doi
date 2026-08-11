# frozen_string_literal: true
module Hyrax
  module DOI
    module DataCiteDOIPresenterBehavior
      extend ActiveSupport::Concern

      delegate :doi_status_when_public, to: :solr_document

      # What DataCite reports, falling back to the depositor's intent when nothing has been
      # registered yet. The two legitimately differ -- a work intended to be findable stays
      # registered while it is private -- so this reads observed state rather than
      # recomputing it from intent and visibility.
      def doi_status
        doi_state.presence || doi_status_when_public
      end
    end
  end
end
