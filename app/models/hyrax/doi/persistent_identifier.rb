# frozen_string_literal: true
module Hyrax
  module DOI
    # One row per identifier per resource, rather than one identifier held in an attribute
    # on the resource: a work may carry several at once -- a DOI and a RAiD, say -- and
    # each has its own state and sync history. The resource's `doi` attribute is a
    # projection of the primary row, kept for indexing and display.
    #
    # See the migration template for why individual columns are shaped as they are.
    class PersistentIdentifier < ActiveRecord::Base
      self.table_name = 'hyrax_doi_persistent_identifiers'

      MINTED = 'minted'
      EXTERNAL = 'external'
      ORIGINS = [MINTED, EXTERNAL].freeze

      validates :scheme, :provider, :value, :origin, presence: true
      validates :origin, inclusion: { in: ORIGINS }
      validates :value, uniqueness: { scope: %i[scheme provider] }

      scope :for_resource, ->(id) { where(resource_id: id.to_s) }
      scope :with_scheme, ->(scheme) { where(scheme: scheme.to_s) }
      scope :minted, -> { where(origin: MINTED) }
      scope :external, -> { where(origin: EXTERNAL) }
      scope :unattached, -> { where(resource_id: nil) }

      def self.primary_for(resource_id:, scheme:)
        for_resource(resource_id).with_scheme(scheme).order(primary: :desc, created_at: :asc).first
      end

      ##
      # A DOI pasted in during autofill belongs to someone else, so it must never be
      # updated or deleted at the provider.
      def minted?
        origin == MINTED
      end

      def external?
        origin == EXTERNAL
      end

      ##
      # @param state [String, nil] provider vocabulary, stored verbatim
      def record_sync(state: nil, error: nil)
        assign_attributes(state: state) if state
        if error
          update(last_error: error)
        else
          update(last_synced_at: Time.current, last_error: nil)
        end
      end
    end
  end
end
