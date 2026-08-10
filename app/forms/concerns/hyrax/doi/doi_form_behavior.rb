# frozen_string_literal: true
module Hyrax
  module DOI
    # Lets a form read and write the DOI its work holds.
    module DOIFormBehavior
      extend ActiveSupport::Concern

      # Modes the DOI tab offers. Which one was chosen decides which of the submitted
      # values the depositor actually meant: a hidden panel still posts its inputs, so
      # both the DOI field and the status radios arrive whatever the choice was.
      MODES = %w[none existing mint].freeze

      # Virtual because doi.yaml sets `form: { display: false }` to keep the field out of the
      # generic "Additional fields" accordion, which also means ResourceForm builds no
      # property of its own. The default reads the work, since nothing else populates a
      # virtual property from the model -- that is what shows an edit form the current DOI.
      included do
        property :doi, virtual: true, default: ->(*) { Array.wrap(model.try(:doi_value)) }
        property :doi_mode, virtual: true
      end

      # Reform populates virtual properties from params but never writes them back, so the
      # DOI has to be pushed onto the work explicitly. Goes through doi_value= rather than
      # doi= because holds_doi_in may have renamed the attribute.
      #
      # A module method, not one defined in `included do`: DataCiteDOIFormBehavior defines
      # its own sync, and two definitions on the same class would replace each other rather
      # than chain through super.
      def sync(*args)
        super
        model.doi_value = Array.wrap(doi).compact_blank
      end

      def validate(params)
        super(reconcile_doi_mode(params))
      end

      private

      # A DOI typed into a panel the depositor then navigated away from is a leftover, not
      # a choice -- except a DOI already recorded on the work, which a mode radio must
      # never silently erase.
      #
      # Assigns into the params rather than converting to a hash first: a controller passes
      # ActionController::Parameters unpermitted, and to_h raises on those. Keys go through
      # helpers because Parameters is indifferent while a plain hash is not.
      def reconcile_doi_mode(params)
        mode = doi_param(params, :doi_mode)
        return params unless mode.in?(MODES)

        params[doi_param_key(params, :doi)] = Array.wrap(model.try(:doi_value)).compact_blank unless mode == 'existing'
        params
      end

      def doi_param(params, key)
        params[key.to_s].presence || params[key]
      end

      # Writes back under whichever form of the key the params already use, so a value is
      # replaced rather than shadowed by a second entry.
      def doi_param_key(params, key)
        params.key?(key.to_s) ? key.to_s : key
      end
    end
  end
end
