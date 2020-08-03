# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::RegisterDOIJob, type: :job do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
    end
  end
  let(:work) { model_class.create(title: ['Moomin']) }

  before do
    # Stubbed here for ActiveJob deserialization
    stub_const("WorkWithDOI", model_class)
  end

  describe '.perform_later' do
    before { ActiveJob::Base.queue_adapter = :test }

    it 'enqueues the job' do
      expect { described_class.perform_later(work) }
        .to enqueue_job(described_class)
        .with(work)
        .on_queue('doi_service')
    end
  end

  describe '.perform' do
    subject(:job) do
      described_class.new.tap do |job|
        job.registrar_opts = registrar_opts
        job.registrar = registrar
      end
    end

    let(:registrar_class) do
      Class.new do
        def initialize(*); end

        def register!(*)
          Struct.new(:identifier).new('10.1234/moomin/123/abc')
        end
      end
    end
    let(:doi) { '10.1234/moomin/123/abc' }
    let(:registrar) { :moomin }
    let(:registrar_opts) { { builder: double(:builder), connection: double(:connection) } }

    before do
      allow(Hyrax.config).to receive(:identifier_registrars).and_return(abstract: Hyrax::Identifier::Registrar, moomin: registrar_class)
    end

    it 'calls the registrar' do
      expect(registrar_class).to receive(:new).with(registrar_opts).and_call_original

      expect { job.perform(work) }
        .to change { work.doi }
        .to eq doi
    end

    # TODO: Write different tests for default first registrar vs requested registrar
  end
end
