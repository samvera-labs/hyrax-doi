# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::SyncDOIJob, type: :job do
  let(:work) { valkyrie_create(:hyrax_work, title: ['Sync me']) }
  let(:registrar) { instance_double(Hyrax::DOI::DataCiteRegistrar, register!: nil) }

  def record_for(provider:, origin: 'minted')
    Hyrax::DOI::PersistentIdentifier.create!(resource_id: work.id.to_s,
                                             resource_type: work.class.name,
                                             scheme: 'doi', provider:,
                                             value: "10.5072/#{provider}", state: 'registered',
                                             origin:, primary: true)
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

  it 'does nothing for a work with no identifier that asked for none' do
    allow(Hyrax::Identifier::Registrar).to receive(:for)

    described_class.perform_now(work.id.to_s)

    expect(Hyrax::Identifier::Registrar).not_to have_received(:for)
  end

  describe 'a work whose depositor asked for a DOI it does not have' do
    let(:work) do
      Hyrax.persister.save(
        resource: DOIWork.new(title: ['Wants one'], doi_status_when_public: 'draft')
      )
    end
    let(:result) do
      Hyrax::DOI::RegistrationResult.new(identifier: '10.5072/fresh', state: 'draft',
                                         changed: true)
    end

    before do
      allow(Hyrax::Identifier::Registrar).to receive(:for)
        .with(:datacite)
        .and_return(instance_double(Hyrax::DOI::DataCiteRegistrar, register!: result))
    end

    it 'mints through the provider configured for the doi scheme' do
      described_class.perform_now(work.id.to_s)

      expect(Hyrax::Identifier::Registrar).to have_received(:for).with(:datacite)
    end

    it 'records the identifier it minted' do
      described_class.perform_now(work.id.to_s)

      record = Hyrax::DOI::PersistentIdentifier.find_by(value: '10.5072/fresh')
      expect(record).to be_present
      expect(record.resource_id).to eq work.id.to_s
      expect(record.state).to eq 'draft'
      expect(record).to be_minted
    end

    it 'stores the DOI on the work, so it indexes and displays' do
      described_class.perform_now(work.id.to_s)

      expect(Array(Hyrax.query_service.find_by(id: work.id).doi)).to eq ['10.5072/fresh']
    end

    it 'mints once however many times it runs' do
      described_class.perform_now(work.id.to_s)
      described_class.perform_now(work.id.to_s)

      expect(Hyrax::DOI::PersistentIdentifier.where(value: '10.5072/fresh').count).to eq 1
    end

    it 'mints nothing for a work that already holds a DOI' do
      held = Hyrax.persister.save(
        resource: DOIWork.new(title: ['Has one'], doi: ['10.5072/already'],
                              doi_status_when_public: 'draft')
      )

      described_class.perform_now(held.id.to_s)

      expect(Hyrax::DOI::PersistentIdentifier.find_by(value: '10.5072/fresh')).to be_nil
    end

    it 'records nothing when the registrar failed' do
      failure = Hyrax::DOI::RegistrationResult.new(errors: ['DataCite requires publisher'])
      allow(Hyrax::Identifier::Registrar).to receive(:for)
        .with(:datacite)
        .and_return(instance_double(Hyrax::DOI::DataCiteRegistrar, register!: failure))

      described_class.perform_now(work.id.to_s)

      expect(Hyrax::DOI::PersistentIdentifier.for_resource(work.id.to_s)).to be_empty
    end
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
