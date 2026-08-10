# frozen_string_literal: true

# A DOI-enabled work type shared by the specs.
#
# A real named class rather than an anonymous one built per example: Valkyrie stores
# `internal_resource` when a resource is saved and resolves it back through `const_get`, so a
# `Class.new` -- even one given a `name` -- cannot round-trip through the persister.
class DOIWork < Hyrax::Work
  include Hyrax::DOI::DOIBehavior
  include Hyrax::DOI::DataCiteDOIBehavior
end
