# frozen_string_literal: true
module Hyrax
  module DOI
    # Writes a NEW Hyrax::FlexibleSchema row rather than editing the current one. A
    # profile's version is its row id, and saved works pin `schema_version` to it, so
    # mutating in place would retroactively change the schema of existing works.
    class FlexibleProfileInstaller
      Result = Struct.new(:schema, :created, :message, keyword_init: true) do
        def created? = created
      end

      PROPERTIES = {
        'doi' => {
          'available_on' => { 'class' => [] },
          'cardinality' => { 'minimum' => 0 },
          'data_type' => 'array',
          'display_label' => { 'default' => 'DOI' },
          'indexing' => %w[doi_ssim doi_tesim],
          'form' => { 'primary' => false, 'display' => false },
          'property_uri' => 'http://purl.org/ontology/bibo/doi',
          'range' => 'http://www.w3.org/2001/XMLSchema#string',
          # Non-empty view options are required: M3SchemaLoader#view_definitions_for
          # drops properties whose view block is empty, and they never render.
          'view' => { 'render_as' => 'doi', 'html_dl' => true }
        }.freeze,
        'doi_status_when_public' => {
          'available_on' => { 'class' => [] },
          'cardinality' => { 'minimum' => 0, 'maximum' => 1 },
          'data_type' => 'string',
          'display_label' => { 'default' => 'DOI status when public' },
          'indexing' => %w[doi_status_when_public_ssi],
          'form' => { 'primary' => false, 'display' => false },
          'property_uri' => 'http://samvera.org/ns/hyrax/doi#doi_status_when_public',
          'range' => 'http://www.w3.org/2001/XMLSchema#string'
        }.freeze
      }.freeze

      # Defaults to every class the current profile declares.
      def initialize(class_names: nil)
        @class_names = class_names
      end

      def call
        current = Hyrax::FlexibleSchema.current_version
        return Result.new(created: false, message: 'No m3 profile found to extend.') if current.blank?
        return Result.new(created: false, message: 'Profile already declares doi.') if already_installed?(current)

        schema = Hyrax::FlexibleSchema.new(profile: merge_into(current))
        return Result.new(schema:, created: false, message: schema.errors.full_messages.to_sentence) unless schema.save

        Result.new(schema:, created: true,
                   message: "Created profile version #{schema.version} with doi properties.")
      end

      # The profile that would be saved, for previewing a change before applying it.
      def merge_into(profile)
        merge_properties(profile.deep_dup)
      end

      private

      def already_installed?(profile)
        profile.dig('properties', 'doi').present?
      end

      def target_classes(profile)
        @class_names || Array(profile['classes']&.keys)
      end

      def merge_properties(profile)
        classes = target_classes(profile)
        profile['properties'] ||= {}
        PROPERTIES.each do |name, config|
          profile['properties'][name] = config.deep_dup.tap do |prop|
            prop['available_on']['class'] = classes
          end
        end
        profile
      end
    end
  end
end
