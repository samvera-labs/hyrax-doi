# frozen_string_literal: true
module Hyrax
  module Doi
    class ApplicationMailer < ActionMailer::Base
      default from: 'from@example.com'
      layout 'mailer'
    end
  end
end
