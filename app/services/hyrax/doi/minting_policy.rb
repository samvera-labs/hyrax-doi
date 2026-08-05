# frozen_string_literal: true
module Hyrax
  module DOI
    # Consulted by the registrar rather than decided inline, so a repository can restrict
    # minting to particular work types -- datasets but not images, say -- without the
    # registrar knowing anything about that choice.
    class MintingPolicy
      # @param work_types [Array<String>, nil] class names allowed to mint; nil allows any
      #   work type that names a registrar
      def initialize(work_types: nil, default_state: 'draft')
        @work_types = work_types
        @default_state = validate_state(default_state)
      end

      attr_reader :work_types, :default_state

      def mintable?(work)
        registrar?(work) && minting_enabled? && eligible_type?(work) && requested?(work)
      end

      private

      def validate_state(state)
        return state.to_s if state.to_s.in?(DataCiteRegistrar::STATES)

        raise ArgumentError, "#{state.inspect} is not one of #{DataCiteRegistrar::STATES.join(', ')}"
      end

      # Naming a registrar is what a scheme concern adds, so it is the signal that a work
      # type can actually mint. The attribute alone is not: a metadata profile could
      # declare doi_status_when_public on a work type with nothing to mint through.
      def registrar?(work)
        work.try(:doi_registrar).present?
      end

      def minting_enabled?
        Flipflop.enabled?(:doi_minting)
      end

      def eligible_type?(work)
        work_types.nil? || work_types.map(&:to_s).include?(work.class.name)
      end

      # Blank means the depositor asked for no DOI.
      def requested?(work)
        work.doi_status_when_public.to_s.in?(DataCiteRegistrar::STATES)
      end
    end
  end
end
