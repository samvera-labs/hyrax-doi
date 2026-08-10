# frozen_string_literal: true
module Hyrax
  module DOI
    # The DOI tab renders the status radios itself, so like the DOI field this stays out of
    # the generic field list while the form still needs to read and write it.
    module DataCiteDOIFormBehavior
      extend ActiveSupport::Concern

      included do
        property :doi_status_when_public,
                 virtual: true,
                 default: ->(*) { model.try(:doi_status_when_public) }
      end

      def sync(*args)
        resource = super
        model.doi_status_when_public = doi_status_when_public.presence
        resource
      end

      private

      # Only the minting mode asks for a status. Recording an existing DOI or choosing no
      # DOI leaves it blank, which is what tells the policy not to mint.
      def reconcile_doi_mode(params)
        params = super
        mode = doi_param(params, :doi_mode)
        return params unless mode.in?(DOIFormBehavior::MODES)

        params[doi_param_key(params, :doi_status_when_public)] = '' unless mode == 'mint'
        params
      end
    end
  end
end
