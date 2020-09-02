# frozen_string_literal: true

module Hyrax
  module DOI
    class Error < ::StandardError; end
    class NotFoundError < Hyrax::DOI::Error; end
  end
end
