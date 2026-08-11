# frozen_string_literal: true

# Stubs the DataCite REST API for specs tagged `:datacite_api`. Expects the example to
# define a `prefix`.
RSpec.configure do |config|
  config.before(datacite_api: true) do
    base = Hyrax::DOI::DataCiteClient::TEST_BASE_URL

    def datacite_doi_body(doi, state)
      { data: { id: doi, type: 'dois', attributes: { doi:, state: } } }.to_json
    end

    # Anything not stubbed below is a DOI DataCite does not have.
    stub_request(:any, /#{Regexp.quote(base)}.*/)
      .to_return(status: 404,
                 body: { errors: [{ status: '404', title: "The resource you are looking for doesn't exist." }] }.to_json)

    stub_request(:get, URI.join(base, 'heartbeat')).to_return(status: 200, body: 'OK')

    stub_request(:get, /#{Regexp.quote(URI.join(base, 'dois').to_s)}\?/)
      .to_return(status: 200, body: { data: [] }.to_json)

    # Minting a draft: only the prefix is sent, and DataCite assigns the suffix.
    stub_request(:post, URI.join(base, 'dois'))
      .with(body: { data: { type: 'dois', attributes: { prefix: } } }.to_json)
      .to_return(status: 201, body: datacite_doi_body("#{prefix}/draft-doi", 'draft'))

    # Submitting metadata. The state returned reflects the event sent, since that is what
    # a caller records.
    %w[draft-doi registered-doi findable-doi].each do |suffix|
      doi = "#{prefix}/#{suffix}"

      stub_request(:put, URI.join(base, "dois/#{doi}"))
        .to_return do |request|
          event = JSON.parse(request.body.presence || '{}').dig('data', 'attributes', 'event')
          state = case event
                  when 'publish' then 'findable'
                  when 'register', 'hide' then 'registered'
                  else 'draft'
                  end
          { status: 200, body: datacite_doi_body(doi, state) }
        end

      stub_request(:get, URI.join(base, "dois/#{doi}"))
        .to_return(status: 200, body: datacite_doi_body(doi, suffix.sub('-doi', '')))

      stub_request(:delete, URI.join(base, "dois/#{doi}")).to_return(status: 204, body: '')
    end
  end
end
