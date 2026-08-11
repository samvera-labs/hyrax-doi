# frozen_string_literal: true
module Hyrax
  module DOI
    module DataCiteDOIBehavior
      extend ActiveSupport::Concern

      # The depositor's intent -- what state the DOI should reach once the work is
      # public -- not the state DataCite currently reports. Observed state lives on the
      # PersistentIdentifier record, because it is provider-specific: DataCite's
      # draft/registered/findable and EZID's reserved/public/unavailable do not share a
      # vocabulary.
      #
      # Blank means do not mint.
      #
      # Skipped when the host already declares it -- see Hyrax::DOI::DOIBehavior.
      included do
        attribute :doi_status_when_public, Valkyrie::Types::String unless has_attribute?(:doi_status_when_public)
      end

      def doi_registrar
        'datacite'
      end
    end
  end
end
