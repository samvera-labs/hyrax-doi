# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Actors::DOIActor do
  subject(:actor)  { described_class.new(next_actor) }
  let(:ability)    { Ability.new(user) }
  let(:env)        { Hyrax::Actors::Environment.new(work, ability, {}) }
  let(:next_actor) { Hyrax::Actors::Terminator.new }
  let(:user)       { FactoryBot.build(:user) }
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
    end
  end
  let(:doi) { nil }
  let(:work) { model_class.create(title: ['Moomin'], doi: doi) }

  before do
    # Stubbed here for ActiveJob deserialization
    stub_const("WorkWithDOI", model_class)

    # Setup a registrar
    allow(Hyrax.config).to receive(:identifier_registrars).and_return(abstract: Hyrax::Identifier::Registrar)
  end

  describe '#create' do
    before { ActiveJob::Base.queue_adapter = :test }

    context 'when the work is not DOI-enabled' do
      let(:work) { FactoryBot.create(:work) }

      it 'does not enqueue a job' do
        expect { actor.create(env) }
          .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
      end
    end

    it 'enqueues a job' do
      expect { actor.create(env) }
        .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        .with(work, registrar: nil, registrar_opts: {})
        .on_queue('doi_service')
    end
  end

  describe '#update' do
    before { ActiveJob::Base.queue_adapter = :test }

    context 'when the work is not DOI-enabled' do
      let(:work) { FactoryBot.create(:work) }

      it 'does not enqueue a job' do
        expect { actor.create(env) }
          .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
      end
    end

    it 'enqueues a job' do
      expect { actor.create(env) }
        .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        .with(work, registrar: nil, registrar_opts: {})
        .on_queue('doi_service')
    end

    context 'when the work implements registrar_name and registrar_opts' do
      let(:model_class) do
        Class.new(GenericWork) do
          include Hyrax::DOI::DOIBehavior

          def doi_registrar
            'moomin'
          end

          def doi_registrar_opts
            { prefix: '10.9999' }
          end
        end
      end

      it 'enqueues a job' do
        expect { actor.create(env) }
          .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
          .with(work, registrar: 'moomin', registrar_opts: { prefix: '10.9999' })
          .on_queue('doi_service')
      end
    end
  end
end
