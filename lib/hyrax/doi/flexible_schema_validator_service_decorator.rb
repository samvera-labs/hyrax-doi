# frozen_string_literal: true
module Hyrax
  module DOI
    # Appends the DOI profile validator to Hyrax's run.
    #
    # Hyrax::FlexibleSchemaValidatorService#validate! is a hardcoded list of calls with no
    # registration API, so a gem has to prepend. `errors` and `warnings` are public
    # readers over arrays mutated in place, so the validator can append through them.
    #
    # Remove this once Hyrax accepts a registration API.
    module FlexibleSchemaValidatorServiceDecorator
      def validate!
        super
        Hyrax::DOI::FlexibleSchemaValidators::DOIValidator.new(
          profile:, errors:, warnings:
        ).validate!
      end
    end
  end
end
