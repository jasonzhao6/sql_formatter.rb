require './sql_formatter'
require 'rspec'

describe SqlFormatter do
  let(:query) { '<overwrite me in examples>' }
  let(:formatter) { described_class.new(query) }
  before { formatter.run }
  subject { formatter.formatted }

  context 'when handling comma' do
    context 'when outside of quotes' do
      context 'when it has no preceding space' do
        let(:query) { 'select a, b' }
        it { should eq('select a, b') }
      end

      context 'when it has preceding space' do
        let(:query) { 'select a , b' }
        it { should eq('select a, b') }
      end
    end

    context 'when inside of quotes' do
      context 'when it has no preceding space' do
        let(:query) { 'select "a, b"' }
        it { should eq('select "a, b"') }
      end

      context 'when it has preceding space' do
        let(:query) { 'select "a , b"' }
        it { should eq('select "a , b"') }
      end
    end
  end
end
