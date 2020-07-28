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
  let(:doi_status_when_public) { nil }
  let(:work) { model_class.create(title: ['Moomin'], doi: doi, doi_status_when_public: doi_status_when_public) }

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

    context 'when a registrar is not configured' do
      it 'does not enqueue a job' do
        expect { actor.create(env) }
          .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
      end
    end

    context 'when doi is blank' do
      context 'when doi expected when public' do
        let(:doi_status_when_public) { :findable }

        it 'enqueues a job' do
          expect { actor.create(env) }
            .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
            .with(work)
            .on_queue('doi_service')
        end
      end

      context 'when doi not expected when public' do
        it 'does not enqueue a job' do
          expect { actor.create(env) }
            .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        end
      end
    end

    context 'when doi is present' do
      let(:doi) { '10.1234/abc' }

      context 'when doi expected when public' do
        let(:doi_status_when_public) { :findable }

        it 'does not enqueue a job' do
          expect { actor.create(env) }
            .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        end
      end

      context 'when doi not expected when public' do
        it 'does not enqueue a job' do
          expect { actor.create(env) }
            .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        end
      end
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

    context 'when a registrar is not configured' do
      it 'does not enqueue a job' do
        expect { actor.create(env) }
          .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
      end
    end

    context 'when doi is blank' do
      context 'when doi expected when public' do
        let(:doi_status_when_public) { :findable }

        it 'enqueues a job' do
          expect { actor.create(env) }
            .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
            .with(work)
            .on_queue('doi_service')
        end
      end

      context 'when doi not expected when public' do
        it 'does not enqueue a job' do
          expect { actor.create(env) }
            .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        end
      end
    end

    context 'when doi is present' do
      let(:doi) { '10.1234/abc' }

      context 'when expected doi status when public changes' do
        let(:doi_status_when_public) { :registered }

        context 'to a known state' do
          before do
            work.doi_status_when_public = :findable
          end

          it 'enqueues a job' do
            expect { actor.create(env) }
              .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
              .with(work)
              .on_queue('doi_service')
          end
        end

        context 'to nil from registerd or findable' do
          before do
            work.doi_status_when_public = nil
          end

          it 'does not enqueue a job' do
            expect { actor.create(env) }
              .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
          end
        end

        context 'to nil from draft' do
          let(:doi_status_when_public) { :draft }

          before do
            work.doi_status_when_public = nil
          end

          it 'enqueues a job' do
            expect { actor.create(env) }
              .to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
              .with(work)
              .on_queue('doi_service')
          end
        end
      end

      context 'when expected doi status when public unchanged' do
        it 'does not enqueue a job' do
          expect { actor.create(env) }
            .not_to have_enqueued_job(Hyrax::DOI::RegisterDOIJob)
        end
      end
    end
  end
end
