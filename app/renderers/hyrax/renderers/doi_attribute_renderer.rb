# frozen_string_literal: true
module Hyrax
  # Lives in Hyrax's namespace, not the gem's: PresentsAttributes#find_renderer_class
  # resolves `render_as` through Renderers.const_get, so it can only find
  # Hyrax::Renderers::*.
  module Renderers
    # DOI, not Doi: the engine registers `inflect.acronym 'DOI'` so that hyrax/doi/*
    # autoloads as Hyrax::DOI::*, and that makes both Zeitwerk and find_renderer_class's
    # `render_as.camelize` expect DOIAttributeRenderer from this filename.
    class DOIAttributeRenderer < AttributeRenderer
      RESOLVER = 'https://doi.org'

      # A draft DOI is reserved but does not resolve, so a link to one is dead. Both row
      # styles suppress it: the show page renders definition lists, tables elsewhere.
      def render
        return '' if suppress?

        super
      end

      def render_dl_row
        return '' if suppress?

        super
      end

      private

      def suppress?
        options[:doi_state].to_s == 'draft'
      end

      def li_value(value)
        bare = value.to_s.sub(%r{\Ahttps?://(dx\.)?doi\.org/}, '')
        link_to(bare, "#{RESOLVER}/#{bare}")
      end
    end
  end
end
