# frozen_string_literal: true
module Hyrax
  module DOI
    module FlexibleSchemaValidators
      # Checks an m3 profile's `doi` property and reports what would not work.
      #
      # Only ever warns. The attribute may be declared on the work class alone, which is
      # supported and invisible to a profile, so a missing property is not an error --
      # unlike Hyrax's own redirects validator, which owns its feature and can insist.
      class DOIValidator
        def initialize(profile:, errors:, warnings: [])
          @profile = profile
          @errors = errors
          @warnings = warnings
        end

        def validate!
          return warn_missing if doi_property.blank?

          warn_no_view_block if view_options.blank?
          warn_unreachable if (available_on_classes & profile_classes).empty?
        end

        private

        attr_reader :profile, :errors, :warnings

        def doi_property
          @doi_property ||= profile&.dig('properties', 'doi')
        end

        def view_options
          doi_property['view'].to_h.except('display_label', 'admin_only', 'editor_only')
        end

        def available_on_classes
          Array(doi_property.dig('available_on', 'class')).compact.map(&:to_s)
        end

        def profile_classes
          Array(profile&.dig('classes')&.keys).compact.map(&:to_s)
        end

        def warn_missing
          warnings << I18n.t('hyrax.doi.flexible_schema_validators.doi_validator.warnings.property_missing')
        end

        def warn_no_view_block
          warnings << I18n.t('hyrax.doi.flexible_schema_validators.doi_validator.warnings.no_view_block')
        end

        def warn_unreachable
          warnings << I18n.t('hyrax.doi.flexible_schema_validators.doi_validator.warnings.unreachable_available_on')
        end
      end
    end
  end
end
