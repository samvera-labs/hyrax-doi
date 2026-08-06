# frozen_string_literal: true
module Hyrax
  module DOI
    # The DOI tab renders the status radios itself, so like the DOI field this stays out of
    # the generic field list while the form still needs to read it.
    module DataCiteDOIFormBehavior
      extend ActiveSupport::Concern

      included do
        delegate :doi_status_when_public, to: :model
      end
    end
  end
end
