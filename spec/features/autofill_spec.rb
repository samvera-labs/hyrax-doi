# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'autofilling the form from DOI', :js do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::DataCiteDOIBehavior
    end
  end
  let(:form_class) do
    Class.new(Hyrax::GenericWorkForm) do
      include Hyrax::DOI::DOIFormBehavior
      include Hyrax::DOI::DataCiteDOIFormBehavior

      self.model_class = GenericWork

      # Ensure we have adequate terms for display_additional_fields? to return true
      # Include basic terms that would normally be in a WorkForm
      self.terms = [:title, :alternative_title, :creator, :contributor, :description, :abstract,
                    :keyword, :license, :rights_statement, :publisher, :date_created,
                    :subject, :language, :identifier, :based_near, :related_url, :resource_type]
      self.required_fields = [:title, :creator, :rights_statement]
    end
  end
  let(:helper_module) do
    Module.new do
      include ::BlacklightHelper
      include Hyrax::BlacklightOverride
      include Hyrax::HyraxHelperBehavior
      include Hyrax::DOI::HelperBehavior
    end
  end
  let(:solr_document_class) do
    Class.new(SolrDocument) do
      include Hyrax::DOI::SolrDocument::DOIBehavior
      include Hyrax::DOI::SolrDocument::DataCiteDOIBehavior
    end
  end
  let(:controller_class) do
    Class.new(::ApplicationController) do
      # Adds Hyrax behaviors to the controller.
      include Hyrax::WorksControllerBehavior
      include Hyrax::BreadcrumbsForWorks
      self.curation_concern_type = GenericWork

      # Use this line if you want to use a custom presenter
      self.show_presenter = Hyrax::GenericWorkPresenter

      helper Hyrax::DOI::Engine.helpers
    end
  end

  let(:user) { create(:admin) }
  let(:input) { File.join(Hyrax::DOI::Engine.root, 'spec', 'fixtures', 'datacite.json') }
  let(:metadata) { Bolognese::Metadata.new(input:) }

  before do
    # Override test app classes and module to simulate generators having been run
    stub_const("GenericWork", model_class)
    stub_const("Hyrax::GenericWorkForm", form_class)
    stub_const("HyraxHelper", helper_module)
    stub_const("SolrDocument", solr_document_class)
    stub_const("Hyrax::GenericWorksController", controller_class)

    # Mock Bolognese so it doesn't have to make a network request
    allow(Bolognese::Metadata).to receive(:new).and_return(metadata)

    allow_any_instance_of(Ability).to receive(:admin_set_with_deposit?).and_return(true)
    allow_any_instance_of(Ability).to receive(:can?).and_call_original
    allow_any_instance_of(Ability).to receive(:can?).with(:new, anything).and_return(true)

    sign_in user
  end

  scenario 'autofills the form' do
    visit "/concern/generic_works/new"

    expect(page).to have_field('generic_work_doi')

    fill_in 'generic_work_doi', with: '10.5438/4k3m-nyvg'
    accept_confirm do
      click_link "doi-autofill-btn"
    end

    # Switch to Descriptions tab to access the form fields
    click_link 'Descriptions' unless page.has_content?('Title')

    expect(page).to have_content('Title')

    click_link 'Additional fields'

    # Expect form fields have been filled in
    expect(page).to have_field('generic_work_title', with: 'Eating your own Dog Food')
    expect(page).to have_field('generic_work_creator', with: 'Fenner, Martin')
    expect(page).to have_field('generic_work_description', with: 'Eating your own dog food is a slang term to describe that an organization '\
                                                                 'should itself use the products and services it provides. For DataCite this '\
                                                                 'means that we should use DOIs with appropriate metadata and strategies for '\
                                                                 'long-term preservation for...')

    # Check that keywords are filled (at least the first one should be there)
    keyword_values = page.all('input[id^="generic_work_keyword"]').map(&:value)
    expect(keyword_values).to include('datacite')
    expect(URI.parse(page.current_url).fragment).to eq 'metadata'
    pending "Autofill needs work"
    expect(keyword_values).to include('doi', 'metadata')
    expect(page).to have_field('generic_work_publisher', with: 'DataCite')
    expect(page).to have_field('generic_work_date_created', with: '2016')
    expect(page).to have_field('generic_work_identifier', with: 'MS-49-3632-5083')
  end
end
