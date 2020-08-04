# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DOI::DataciteRegistrar do

  subject { described_class.new }

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
  end

  describe '#register?' do
    context 'when the work is not DOI-enabled' do
      let(:work) { FactoryBot.create(:work) }

      it 'is false' do
        expect(subject.register?(object: work)).to eq false
      end
    end

    context 'when doi is blank' do
      context 'when doi expected when public' do
        let(:doi_status_when_public) { :findable }

        it 'is true' do
          expect(subject.register?(object: work)).to eq true
        end
      end

      context 'when doi not expected when public' do
        it 'is false' do
          expect(subject.register?(object: work)).to eq false
        end
      end
    end

    context 'when doi is present' do
      let(:doi) { '10.1234/abc' }

      context 'when doi expected when public' do
        let(:doi_status_when_public) { :findable }

        it 'is false' do
          expect(subject.register?(object: work)).to eq false
        end
      end

      context 'when doi not expected when public' do
        it 'is false' do
          expect(subject.register?(object: work)).to eq false
        end
      end
    end
  end
end