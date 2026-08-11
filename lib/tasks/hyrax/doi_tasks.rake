# frozen_string_literal: true
namespace :hyrax do
  namespace :doi do
    desc 'Add doi properties to the current m3 profile (creates a new profile version)'
    task install_flexible_profile: :environment do
      class_names = ENV['CLASSES']&.split(',')&.map(&:strip).presence
      result = Hyrax::DOI::FlexibleProfileInstaller.new(class_names:).call

      puts result.message
      exit(1) unless result.created?
    end
  end
end
