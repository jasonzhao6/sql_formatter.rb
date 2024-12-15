require './sql_formatter'
require 'rspec'

describe SqlFormatter do
  let(:query) { '<overwrite me in examples>' }
  let(:formatter) { described_class.new(query) }
  before { formatter.run }
  subject { formatter.formatted }

  context 'when handling space' do
    context 'when there is a single space' do
      let(:query) { 'select a' }
      it { should eq('select a') }
    end

    context 'when there are consecutive spaces' do
      context 'when outside of quotes' do
        let(:query) { 'select  a' }
        it { should eq('select a') }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a  b"' }
        it { should eq('select "a  b"') }
      end
    end
  end

  context 'when handling comma' do
    context 'when it has no preceding space' do
      let(:query) { 'select a, b' }
      it { should eq('select a, b') }
    end

    context 'when it has preceding space' do
      context 'when outside of quotes' do
        let(:query) { 'select a , b' }
        it { should eq('select a, b') }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a , b"' }
        it { should eq('select "a , b"') }
      end
    end
  end

  context 'when handling operators' do
    context 'when there is one' do
      let(:query) { 'where id = 1' }
      it { should eq('where id = 1') }
    end

    context 'when there are two' do
      let(:query) { 'where id <> 1' }
      it { should eq('where id <> 1') }
    end
  end

  context 'when handling new lines and indentations' do
    context 'when there is only primary keywords' do
      let(:query) { 'select * from a join b where a.id = 1 order by 1;' }
      it { should eq(expected) }

      let(:expected) do
        <<~SQL.chomp
          select *
          from a
          join b
          where a.id = 1
          order by 1
          ;
        SQL
      end
    end

    context 'when there are also secondary keywords' do
      let(:query) { 'select * from a join b on a.id = b.id where a.id = 1 and a.id != 2 or a.id = 3 order by 1\\G' }
      it { should eq(expected) }

      let(:expected) do
        <<~SQL.chomp
          select *
          from a
          join b
            on a.id = b.id
          where a.id = 1
            and a.id != 2
            or a.id = 3
          order by 1
          \\G
        SQL
      end
    end
  end
end
