# frozen_string_literal: true
module Hyrax
  module DOI
    module MintButtonHelper
      # Adds the button to the show page's action row. Hyrax gained show_actions_for after
      # this gem's minimum version, so defer to it when present and stay silent otherwise:
      # on an older Hyrax nothing renders the action partials anyway, and an application
      # wanting the button renders _show_action_mint_doi itself.
      def show_actions_for(presenter:)
        (defined?(super) ? super : []) + ['mint_doi']
      end

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
