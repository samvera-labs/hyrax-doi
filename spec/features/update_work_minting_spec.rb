# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Minting a DOI for an existing work", js: true do
  let(:user) { create(:user) }
  let!(:account) { create(:account) }
  let(:attributes) do
    {
      title: ["Work title"],
      doi_status_when_public: nil,
      visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC,
      user: user,
      creator: ["Johnny Testison"],
      institution: ["University of Virginia"],
      resource_type: ["Blog post"]
    }
  end
  let!(:work) { create(:work, attributes) }
  let(:work_type) { work.class.name.underscore }

  let!(:admin_set_id) { AdminSet.find_or_create_default_admin_set_id }
  let!(:permission_template) { Hyrax::PermissionTemplate.find_or_create_by!(source_id: admin_set_id) }
  let!(:workflow) do
    Sipity::Workflow.create!(
      active: true,
      name: "test-workflow",
      permission_template: permission_template
    )
  end

  let(:prefix) { "10.23716" }
  let(:datacite_endpoint_attributes) do
    {
      mode: :test,
      prefix: prefix,
      username: "VJKA.JCRXZG-LOCAL",
      password: "password"
    }
  end
  let(:account) do
    account = create(:account)
    account.create_datacite_endpoint(datacite_endpoint_attributes)
    account.save
    account
  end
  let(:site) { Site.create(account: account) }

  before do
    allow(Site).to receive(:instance).and_return(site)
    allow(Flipflop).to receive(:enabled?).and_call_original
    allow(Flipflop).to receive(:enabled?).with(:doi_minting).and_return(true)

    # NOTE: The default method from Bolognese isn"t sorting the identifiers, so they are returned in a random order,
    # which makes mocking the response impossible as WebMock thinks its a new request.
    Bolognese::DataciteUtils.class_eval do
      def insert_alternate_identifiers(xml)
        alternate_identifiers = Array.wrap(identifiers).select { |r| r["identifierType"] != "DOI" }.sort_by { |h| h["identifier"] }
        return xml if alternate_identifiers.blank?

        xml.alternateIdentifiers do
          Array.wrap(alternate_identifiers).each do |alternate_identifier|
            xml.alternateIdentifier(alternate_identifier["identifier"], "alternateIdentifierType": alternate_identifier["identifierType"])
          end
        end
      end
    end

    # Create a single action that can be taken
    Sipity::WorkflowAction.create!(name: "submit", workflow: workflow)

    # Grant the user access to deposit into the admin set.
    Hyrax::PermissionTemplateAccess.create!(
      permission_template_id: permission_template.id,
      agent_type: "user",
      agent_id: user.user_key,
      access: "deposit"
    )

    # Ensure that the _url methods have a host when creating XML data
    Capybara.default_host = "http://#{account.cname}"
    default_url_options[:host] = "http://#{account.cname}"

    login_as user
  end

  describe "when the user edits a work without a minted DOI" do
    before do
      visit "/concern/#{work_type.to_s.pluralize}/#{work.id}/edit"
    end

    it "Sets up the page correctly" do
      expect(page).to have_content "Edit Work"

      find("a[role=tab]", text: "DOI").click

      # have_field with nil value isn"t working properly here
      expect(find_field("DOI").value).to eq ""
      expect(find(:radio_button, "generic_work[doi_status_when_public]", checked: true).value).to eq ""
      expect(find(:radio_button, "generic_work[visibility]", checked: true).value).to eq "open"

      find("a[role=tab]", text: "Description").click
      expect(page).to have_field("Title", with: work.title.first)
    end

    context "when the user selects `findable`" do
      let(:new_title) { "New work title" }
      let(:doi) { "#{prefix}/kgkc-nn31" }

      let(:response_fixture) { File.read Rails.root.join("..", "fixtures", "datacite", "put_metadata.xml") }
      let(:common_headers) do
        {
          "Accept": "*/*",
          "Accept-Encoding": "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization": "Basic VkpLQS5KQ1JYWkctTE9DQUw6cGFzc3dvcmQ=",
          "User-Agent": "Faraday v0.17.4"
        }
      end
      let(:json_headers) do
        common_headers.merge("Content-Type": "application/json")
      end
      let(:xml_headers) do
        common_headers.merge("Content-Type": "application/xml;charset=UTF-8")
      end
      let(:text_headers) do
        common_headers.merge("Content-Type": "text/plain;charset=UTF-8")
      end

      before do
        # The initial request to create_draft_doi
        stub_request(:post, "https://api.test.datacite.org/dois")
          .with(body: { "data": { "type": "dois", "attributes": { "prefix": prefix } } }.to_json, headers: json_headers)
          .to_return(status: 201, body: { "data": { "id": doi, "type": "dois", "attributes": {} } }.to_json, headers: {})

        # Send the work data to datacite
        stub_request(:put, "https://mds.test.datacite.org/metadata/#{doi}")
          .with(body: response_fixture, headers: xml_headers)
          .to_return(status: 201, body: "", headers: {})

        # Register the URL
        stub_request(:put, "https://mds.test.datacite.org/doi/#{doi}")
          .with(body: "doi=#{doi}\nurl=http://#{account.cname}/concern/generic_works/#{work.id}", headers: text_headers)
          .to_return(status: 201, body: "", headers: {})
      end

      it "mints a DOI" do
        perform_enqueued_jobs do
          choose "Findable"
          choose "generic_work_visibility_open"
          check "agreement"

          find("a[role=tab]", text: "Description").click
          fill_in("Title", with: new_title)
          find("input[type=submit]").click

          # Ensure we end up on the right page
          expect(page).to have_selector("h1", text: "Work", wait: 10)
          expect(page).to have_selector("h2", text: new_title)
          expect(page).to have_selector("a", text: "https://doi.org/#{doi}")
        end
      end
    end
  end
end
