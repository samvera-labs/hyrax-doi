# frozen_string_literal: true
require 'rails/generators'
require 'rails/generators/model_helpers'

module Hyrax
  module DOI
    class AddToWorkTypeGenerator < Rails::Generators::NamedBase
      # ActiveSupport can interpret models as plural which causes
      # counter-intuitive route paths. Pull in ModelHelpers from
      # Rails which warns users about pluralization when generating
      # new models or scaffolds.
      include Rails::Generators::ModelHelpers

      # Required due to non-standard capitalization of DOI namespace
      namespace 'hyrax:doi:add_to_work_type'
      # Same as adding --skip-namespace flag to generator call
      # This removes the hyrax/doi namespace from class_path
      # Namespaces passed as the argument will still appear in class_path
      class_option :skip_namespace, default: true

      class_option :datacite, type: :boolean, default: true,
                              desc: 'Add DataCite behavior, which is what makes the work type mintable.'

      desc 'Add DOI support to given work type'
      def inject_into_model
        inject_after(model_file, /class \S+ < Hyrax::Work\b.*\n/, concerns('Hyrax::DOI'), indent: '  ')
      end

      desc 'Add DOI support to given work type form'
      def inject_into_form
        inject_after(form_file, /< Hyrax::Forms::ResourceForm\(\S+\)\s*\n/,
                     concerns('Hyrax::DOI', suffix: 'FormBehavior'), indent: '  ')
      end

      private

      # A Valkyrie work type has no presenter of its own -- Hyrax uses
      # Hyrax::WorkShowPresenter unless an application writes one -- so the presenter
      # behaviors are documented rather than injected. The show page reads its DOI through
      # the renderer and the SolrDocument either way.
      def concerns(namespace, suffix: 'Behavior')
        names = ["#{namespace}::DOI#{suffix}"]
        names << "#{namespace}::DataCiteDOI#{suffix}" if options[:datacite]
        names
      end

      def inject_after(path, anchor, modules, indent:)
        unless File.exist?(path)
          say_status :skip, "#{path} not found", :yellow
          return
        end

        body = modules.map { |m| "#{indent}include #{m}\n" }.join
        # force: false leaves an already-configured work type alone, so the generator can
        # be re-run after adding --datacite.
        inject_into_file path, body, after: anchor, force: false
      end

      def model_file
        File.join(destination_root, 'app', 'models', *class_path, "#{file_name}.rb")
      end

      def form_file
        File.join(destination_root, 'app', 'forms', *class_path, "#{file_name}_form.rb")
      end
    end
  end
end
