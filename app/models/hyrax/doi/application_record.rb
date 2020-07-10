module Hyrax
  module Doi
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
