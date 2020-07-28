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
          # Return early if work isn't DOI enabled
          return false unless env.curation_concern.class.ancestors.include? Hyrax::DOI::DOIBehavior

          # Create DOI if one is wanted eventually and one doesn't already exist
          if env.curation_concern.doi.blank? && env.curation_concern.doi_status_when_public.in?([:draft, :registered, :findable])
            return true
          end

          # Update if doi_status_when_public changes to another possible status
          # FIXME: Come up with a cleaner way to deal with this without making it too complex?
          if (env.curation_concern.doi.present? && env.curation_concern.doi_status_when_public_changed? &&
               (env.curation_concern.doi_status_when_public_changed?(from: nil, to: :draft) ||
                env.curation_concern.doi_status_when_public_changed?(from: nil, to: :registered) ||
                env.curation_concern.doi_status_when_public_changed?(from: nil, to: :findable) ||
                env.curation_concern.doi_status_when_public_changed?(from: :draft, to: nil) ||
                env.curation_concern.doi_status_when_public_changed?(from: :draft, to: :registered) ||
                env.curation_concern.doi_status_when_public_changed?(from: :draft, to: :findable) ||
                env.curation_concern.doi_status_when_public_changed?(from: :registered, to: :findable) ||
                env.curation_concern.doi_status_when_public_changed?(from: :findable, to: :registered)))
            return true
          end

          # TODO: When registar required metadata changes
          # Need to know registrar to do this?
          # if env.curation_concern.changes.keys.any? { |k| k.in?(registrar::REQUIRED_METADATA)}

          # TODO: When work becomes public or ceases to be public
          # The code below doesn't work because visibility_changed?(to:/from:) doesn't work because visibility isn't setup with ActiveModel::Dirty
          #if (env.curation_concern.visibility_changed?(to: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ) ||
          #    env.curation_concern.visibility_changed?(from: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC ))
          #  return true
          #end

          false
        end
    end
  end
end
