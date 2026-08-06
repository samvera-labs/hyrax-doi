# frozen_string_literal: true
module Hyrax
  module DOI
    # The engine wires these itself, so including this is not required. It stays for hosts
    # that already include it, and for an application that wires helpers explicitly.
    module HelperBehavior
      include Hyrax::DOI::WorkFormHelper
      include Hyrax::DOI::MintButtonHelper
    end
  end
end
