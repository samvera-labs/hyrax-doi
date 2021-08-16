# frozen_string_literal: true

Flipflop.configure do
  feature :doi_minting,
          default: true,
          description: "Toggle the DOI minting for this tenant"
end
