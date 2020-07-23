# frozen_string_literal: true
module Hyrax
  module DOI
    class ApplicationMailer < ActionMailer::Base
      default from: 'from@example.com'
      layout 'mailer'
    end
  end
end
