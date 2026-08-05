# frozen_string_literal: true
module Hyrax
  module DOI
    module MintButtonHelper
      # Whether to offer minting for a work on its show page. Editing the work is the
      # right permission: minting changes what the work publishes about itself.
      #
      # A presenter wraps a SolrDocument rather than the work, so this asks only what a
      # presenter can answer. The registrar checks the policy again against the real work
      # before submitting anything.
      def show_mint_doi_button?(presenter, ability: current_ability)
        return false unless Flipflop.enabled?(:doi_minting)
        return false unless presenter.try(:doi_status_when_public).to_s.in?(DataCiteRegistrar::STATES)
        return false if presenter.try(:doi).present?
        return false unless eligible_work_type?(presenter)

        ability.can?(:edit, presenter)
      end

      private

      def eligible_work_type?(presenter)
        allowed = Hyrax::DOI.config.minting_policy.work_types
        return true if allowed.nil?

        allowed.map(&:to_s).include?(presenter.try(:model)&.name)
      end
    end
  end
end
