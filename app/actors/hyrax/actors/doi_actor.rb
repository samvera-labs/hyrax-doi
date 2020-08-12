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
        create_or_update_doi(env.curation_concern) && next_actor.create(env)
      end

      ##
      # @return [Boolean]
      #
      # @see Hyrax::Actors::AbstractActor
      def update(env)
        create_or_update_doi(env.curation_concern) && next_actor.update(env)
      end

      private

      def create_or_update_doi(work)
        return true unless doi_enabled_work_type?(work)

        Hyrax::DOI::RegisterDOIJob.perform_later(work, registrar: find_registrar(work), registrar_opts: work.doi_registrar_opts)
      end

      # Check if work is DOI enabled
      def doi_enabled_work_type?(work)
        work.class.ancestors.include? Hyrax::DOI::DOIBehavior
      end

      def find_registrar(work)
        # Ensure that registrar is a string because ActiveJob cannot serialize a symbol
        # Do this as a two step process because nil.to_s is ""
        # which causes the job not to fallback to its default
        registrar_name = work.doi_registrar
        registrar_name.present? ? registrar_name.to_s : nil
      end
    end
  end
end
