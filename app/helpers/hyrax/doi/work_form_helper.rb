# frozen_string_literal: true
module Hyrax
  module DOI
    module WorkFormHelper
      def form_tabs_for(form:)
        doi_tab?(form) ? super.prepend('doi') : super
      end

      # Asks the form's resource rather than its class: under HYRAX_FLEXIBLE the profile
      # puts attributes on the instance's singleton class, so a work type that gets `doi`
      # from an m3 profile alone answers respond_to? while its class ancestry shows
      # nothing. Mirrors Hyrax::RedirectsTabHelper#redirects_tab?.
      def doi_tab?(form)
        target = form.respond_to?(:model) ? form.model : form
        target.respond_to?(:doi)
      end

      # Which fields the form should warn about leaving blank, as CSS selectors paired
      # with the label the work itself uses. Skips fields the work type does not have, so
      # a repository with no `creator` gets no selector matching nothing.
      def doi_required_fields(form)
        param_key = form.model_name.param_key
        Hyrax::DOI::DataCiteSerializer.required_work_fields.filter_map do |field|
          next unless form.model.respond_to?(field)

          { selector: ".#{param_key}_#{field}", label: label_for_doi_field(form, field) }
        end
      end

      private

      def label_for_doi_field(form, field)
        form.model_class.human_attribute_name(field)
      end
    end
  end
end
