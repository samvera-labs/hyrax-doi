# frozen_string_literal: true
module Hyrax
  module DOI
    class HyraxDOIController < ApplicationController
      before_action :check_authorization

      def create_draft_doi
        if Flipflop.enabled?(:doi_minting)
          draft_doi = mint_draft_doi

          respond_to do |format|
            format.js { render js: autofill_field(doi_attribute_name, draft_doi), status: :created }
            format.json { render_json_response(response_type: :created, options: { data: draft_doi }) }
          end
        else
          respond_to do |format|
            format.js { render plain: I18n.t("errors.doi_minting.disabled"), status: :internal_error }
            format.json { render_json_response(response_type: :internal_error, message: I18n.t("errors.doi_minting.disabled")) }
          end
        end
      rescue Hyrax::DOI::DataCiteClient::Error => e
        respond_to do |format|
          format.js { render plain: e.message, status: :internal_server_error }
          format.json { render_json_response(response_type: :internal_error, message: e.full_message) }
        end
      end

      private

      def check_authorization
        raise Hydra::AccessDenied unless current_ability.can_create_any_work?
      end

      def mint_draft_doi
        doi_registrar.mint_draft_doi
      end

      def doi_registrar
        # TODO: generalize this
        Hyrax::Identifier::Registrar.for(:datacite, {})
      end

      def field_selector(attribute_name)
        ".#{params[:curation_concern]}_#{attribute_name}"
      end

      def doi_attribute_name
        params[:attribute] || "doi"
      end


      # TODO: make this configurable
      def js_fields
        %w(title)
      end

      # TODO: Move this out to a partial that gets rendered?
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def autofill_field(attribute_name, value)
        js = []
        # TODO: add error handling in the JS so an error doesn't leave the autofilling incomplete
        # rubocop:disable Lint/UselessAssignment
        position = value if attribute_name == 'funder_position'
        # rubocop:enable Lint/UselessAssignment
        js << "  doi_button_var = document.querySelectorAll('#{field_selector(attribute_name)} button.add');"
        Array(value).each_with_index do |v, index|
          # Is this the right way to do this?
          # Need to be smarter to see if all repeated fields are filled before trying to create a new one by clicking?
          unless index.zero?
            js << "if(doi_button_var[0] != undefined) {"
            js << "document.querySelectorAll('#{field_selector(attribute_name)} button.add')[0].click();"
            js << "}"
          end
          if attribute_name.include?('date')
            dates = v.split('-')
            js << "if(document.querySelectorAll('#{field_selector(attribute_name)} .form-control')[#{index}] != undefined) {"
            js << "  document.querySelectorAll('#{field_selector(attribute_name)} .form-control#date_year')[#{index}].value = '#{helpers.escape_javascript(dates[0].to_i.to_s)}';" if dates[0]
            js << "  document.querySelectorAll('#{field_selector(attribute_name)} .form-control#date_month')[#{index}].value = '#{helpers.escape_javascript(dates[1].to_i.to_s)}';" if dates[1]
            js << "  document.querySelectorAll('#{field_selector(attribute_name)} .form-control#date_day')[#{index}].value = '#{helpers.escape_javascript(dates[2].to_i.to_s)}';" if dates[2]
            js << "}"
            next
          end

          js << "$.when(document.querySelectorAll('a.add_#{attribute_name.split('_')&.first}')[#{index}].click()).then(function() {" if js_fields.include?(attribute_name) && index < Array(value).length - 1
          js << "  doi_form_var = document.querySelectorAll('#{field_selector(attribute_name)} .form-control, #{field_selector(attribute_name)} .select-control');"
          js << "  if(doi_form_var[#{index}] != undefined) {"
          js << "    document.querySelectorAll('#{field_selector(attribute_name)} .form-control, #{field_selector(attribute_name)} .select-control')[#{index}].value = '#{helpers.escape_javascript(v)}';"
          js << "    $(document.querySelectorAll('#{field_selector(attribute_name)} .form-control, #{field_selector(attribute_name)} .select-control')[#{index}]).change();" if js_fields.include?(attribute_name)
          js << "  }"
          js << "})" if ajs_fields.include?(attribute_name) && index < Array(value).length - 1
        end
        js.reject(&:blank?).join("\n")
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength      

      # Override of Hyrax method (See https://github.com/samvera/hyrax/pull/4495)
      # render a json response for +response_type+
      def render_json_response(response_type: :success, message: nil, options: {})
        json_body = Hyrax::API.generate_response_body(response_type: response_type, message: message, options: options)
        render json: json_body, status: Hyrax::API.default_responses[response_type][:code]
      end
    end
  end
end
