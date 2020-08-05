# frozen_string_literal: true
module Hyrax
  module Actors
    ##
    # An actor that registers a DOI using the configured registar
    # This actor should come after the model actor which saves the work
    #
    # @example use in middleware
    #   stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
    #     # middleware.use OtherMiddleware
    #     middleware.use Hyrax::Actors::DOIActor
    #     # middleware.use MoreMiddleware
    #   end
    #
    #   env = Hyrax::Actors::Environment.new(object, ability, attributes)
    #   last_actor = Hyrax::Actors::Terminator.new
    #   stack.build(last_actor).create(env)
    class DOIActor < AbstractActor
      ##
      # @return [Boolean]
      #
      # @see Hyrax::Actors::AbstractActor
      def create(env)
        # Assume the model actor has already run and saved the work
        create_or_update_doi(env) && next_actor.create(env)
      end

      ##
      # @return [Boolean]
      #
      # @see Hyrax::Actors::AbstractActor
      def update(env)
        create_or_update_doi(env) && next_actor.update(env)
      end

      private

      def create_or_update_doi(env)
        return true unless Hyrax.config.identifier_registrars.present? && should_create_or_update_doi?(env)

        Hyrax::DOI::RegisterDOIJob.perform_later(env.curation_concern)
      end

      # Determine if doi job should be enqueued or not
      def should_create_or_update_doi?(env)
        doi_enabled_work_type?(env) &&
        doi_minting_enabled? &&
        (doi_requested?(env) ||
         doi_status_change?(env) ||
         doi_metadata_changed?(env) ||
         public_visibility_changed?(env))
      end

      # Check if work is DOI enabled
      def doi_enabled_work_type?(env)
        env.curation_concern.class.ancestors.include? Hyrax::DOI::DOIBehavior
      end

      def doi_minting_enabled?
        # Check feature flipper (needs to be per tenant per work type?)
        return true
      end

      # Check if DOI is wanted eventually and one doesn't already exist
      def doi_requested?(env)
        env.curation_concern.doi.blank? && env.curation_concern.doi_status_when_public.in?([:draft, :registered, :findable])
      end

      # Check if doi_status_when_public changes to another possible status
      def doi_status_change?(env)
        env.curation_concern.doi.present? && env.curation_concern.doi_status_when_public_changed? &&
          (env.curation_concern.doi_status_when_public_changed?(from: nil, to: :draft) ||
           env.curation_concern.doi_status_when_public_changed?(from: nil, to: :registered) ||
           env.curation_concern.doi_status_when_public_changed?(from: nil, to: :findable) ||
           env.curation_concern.doi_status_when_public_changed?(from: :draft, to: nil) ||
           env.curation_concern.doi_status_when_public_changed?(from: :draft, to: :registered) ||
           env.curation_concern.doi_status_when_public_changed?(from: :draft, to: :findable) ||
           env.curation_concern.doi_status_when_public_changed?(from: :registered, to: :findable) ||
           env.curation_concern.doi_status_when_public_changed?(from: :findable, to: :registered))
      end

      # Check if metadata sent to the registrar has changed 
      def doi_metadata_changed?(env)
        # TODO: When registar rmetadata changes
        # Need to know registrar to do this?
        # if env.curation_concern.changes.keys.any? { |k| k.in?(registrar::METADATA_FIELDS)}
        return false
      end

      # Check if the work becomes public or ceases being public
      def public_visibility_changed?(env)
        # TODO: When work becomes public or ceases to be public
        # The code below doesn't work because visibility_changed?(to:/from:) doesn't work because visibility isn't setup with ActiveModel::Dirty
        # if (env.curation_concern.visibility_changed?(to: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ) ||
        #    env.curation_concern.visibility_changed?(from: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ))
        #  return true
        # end
        return false
      end
    end
  end
end
