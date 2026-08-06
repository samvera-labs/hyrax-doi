# frozen_string_literal: true
module Hyrax
  module DOI
    # Gives a form access to the DOI its work holds. config/metadata/doi.yaml sets
    # `form: { display: false }`, which keeps the field out of primary_terms and
    # secondary_terms so it does not also appear in the generic "Additional fields"
    # accordion -- but that also means ResourceForm builds no accessor for it, and the DOI
    # tab reads f.object.doi.
    module DOIFormBehavior
      extend ActiveSupport::Concern

      included do
        delegate :doi, to: :model
      end
    end
  end
end
