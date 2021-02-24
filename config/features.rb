# frozen_string_literal: true

FlipFlop.configure do
  feature :doi,
          default: true,
          description: "Toggle the DOI minting for this tenant"
end
