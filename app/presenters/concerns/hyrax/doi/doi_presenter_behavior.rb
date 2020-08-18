# frozen_string_literal: true
module Hyrax
  module DOI
    module DOIPresenterBehavior
      extend ActiveSupport::Concern

      delegate :doi, to: :solr_document

      def doi_link
        doi.present? ? "https://doi.org/#{doi}" : nil
      end
    end
  end
end
