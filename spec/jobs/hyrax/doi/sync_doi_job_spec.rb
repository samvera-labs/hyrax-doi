# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::SyncDOIJob, type: :job do
  let(:work) { valkyrie_create(:hyrax_work, title: ['Sync me']) }
  let(:registrar) { instance_double(Hyrax::DOI::DataCiteRegistrar, register!: nil) }

  def record_for(provider:, origin: 'minted')
    Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                             resource_type: work.class.name,
                                             scheme: 'doi', provider: provider,
                                             value: "10.5072/#{provider}", state: 'registered',
                                             origin: origin, primary: true)
  end

  it 'enqueues on the ingest queue' do
    ActiveJob::Base.queue_adapter = :test

    expect { described_class.perform_later(work.id.to_s) }
      .to enqueue_job(described_class).on_queue(Hyrax.config.ingest_queue_name)
  end

  it 'registers through the provider that minted the identifier' do
    record_for(provider: 'datacite')
    allow(Hyrax::Identifier::Registrar).to receive(:for).with(:datacite).and_return(registrar)

    described_class.perform_now(work.id.to_s)

    expect(registrar).to have_received(:register!).with(object: an_object_having_attributes(id: work.id))
  end

  it 'does nothing for a work with no identifier' do
    allow(Hyrax::Identifier::Registrar).to receive(:for)

    described_class.perform_now(work.id.to_s)

    expect(Hyrax::Identifier::Registrar).not_to have_received(:for)
  end

  it 'does nothing for an identifier we did not mint' do
    record_for(provider: 'external', origin: 'external')
    allow(Hyrax::Identifier::Registrar).to receive(:for)

    described_class.perform_now(work.id.to_s)

    expect(Hyrax::Identifier::Registrar).not_to have_received(:for)
  end

  it 'exits quietly when the work is gone' do
    record_for(provider: 'datacite')
    allow(Hyrax.query_service).to receive(:find_by)
      .and_raise(Valkyrie::Persistence::ObjectNotFoundError)

    expect { described_class.perform_now(work.id.to_s) }.not_to raise_error
  end
end
