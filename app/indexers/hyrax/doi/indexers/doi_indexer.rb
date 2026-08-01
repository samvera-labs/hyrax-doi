# frozen_string_literal: true
module Hyrax
  module DOI
    module Indexers
      # Uses ||= so it is a no-op where a metadata profile or YAML schema already
      # supplies these keys, and fills them in where it does not -- the attribute may
      # be declared on the class alone, which no schema loader knows about.
      #
      #   class WorkIndexer < Hyrax::Indexers::PcdmObjectIndexer
      #     include Hyrax::DOI::Indexers::DOIIndexer
      #   end
      module DOIIndexer
        def to_solr(*args)
          super.tap do |document|
            next document unless resource.respond_to?(:doi_value)

            document['doi_ssim'] ||= resource.doi_value
            document['doi_tesim'] ||= resource.doi_value
            document['doi_status_when_public_ssi'] ||= resource.try(:doi_status_when_public)
            document['doi_state_ssi'] ||= resource.try(:doi_state)
          end
        end
      end
    end
  end
end
