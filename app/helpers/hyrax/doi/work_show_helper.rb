# frozen_string_literal: true
module Hyrax
  module DOI
    module WorkShowHelper
      def render_doi?(presenter)
        return false unless presenter.class.ancestors.include? Hyrax::DOI::DOIPresenterBehavior
        return presenter.doi_status_when_public.in? [nil, 'registered', 'findable'] if presenter.class.ancestors.include? Hyrax::DOI::DataCiteDOIPresenterBehavior
        true
      end
    end
  end
end
