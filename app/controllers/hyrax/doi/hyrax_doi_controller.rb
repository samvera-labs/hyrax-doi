# frozen_string_literal: true
module Hyrax
  module DOI
    class HyraxDOIController < ApplicationController
      before_action :check_deposit_authorization, only: %i[create_draft_doi autofill]
      before_action :check_edit_authorization, only: :mint

      # Reserves a DOI without submitting the deposit form, so a depositor can embed it in
      # the file they are about to upload.
      def create_draft_doi
        return render_disabled unless Flipflop.enabled?(:doi_minting)

        render json: { doi: doi_registrar.mint_draft_doi }, status: :created
      rescue Hyrax::DOI::DataCiteClient::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      def mint
        return render_disabled unless Flipflop.enabled?(:doi_minting)

        result = doi_registrar.register!(object: work)
        if result.success?
          render json: { doi: result.identifier, state: result.state }, status: :ok
        else
          render json: { error: result.error_message }, status: :unprocessable_entity
        end
      rescue Hyrax::DOI::DataCiteClient::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      def autofill
        render json: { attributes: Hyrax::DOI::DOIResolver.new.attributes_for(params.require(:doi)) },
               status: :ok
      rescue Hyrax::DOI::NotFoundError => e
        render json: { error: e.message }, status: :not_found
      rescue Hyrax::DOI::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      private

      # Reserving a draft DOI needs deposit rights, not rights over any particular work:
      # there is no work yet when the deposit form asks for one.
      def check_deposit_authorization
        render json: { error: 'Not authorized.' }, status: :forbidden unless current_ability.can_create_any_work?
      end

      def check_edit_authorization
        render json: { error: 'Not authorized.' }, status: :forbidden unless current_ability.can?(:edit, work)
      end

      def work
        return @work if defined?(@work)

        @work = Hyrax.query_service.find_by(id: params[:id])
      end

      def doi_registrar
        Hyrax::Identifier::Registrar.for(provider_for_doi.to_sym)
      end

      def provider_for_doi
        Hyrax::DOI.config.provider_for('doi') ||
          raise(Hyrax::DOI::Error, 'No provider is configured for the doi scheme.')
      end

      def render_disabled
        render json: { error: I18n.t('errors.doi_minting.disabled') }, status: :service_unavailable
      end
    end
  end
end
