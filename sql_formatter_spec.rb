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
      it { should eq(query) }
    end

    context 'when there are consecutive spaces' do
      context 'when outside of quotes' do
        let(:query) { 'select  a' }
        it { should eq('select a') }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a  b"' }
        it { should eq(query) }
      end
    end
  end

  context 'when handling operator' do
    context 'when operator has one char' do
      context 'when it has preceding and succeeding spaces' do
        let(:query) { 'where a = 1' }
        it { should eq(query) }
      end

      context 'when it has no preceding and succeeding spaces' do
        context 'when outside of quotes' do
          let(:query) { 'where a=1' }
          it { should eq('where a = 1') }
        end

        context 'when inside of quotes' do
          let(:query) { 'select "a=1"' }
          it { should eq(query) }
        end
      end
    end

    context 'when operator has two chars' do
      context 'when it has preceding and succeeding spaces' do
        let(:query) { 'where a != 1' }
        it { should eq(query) }
      end

      context 'when it has no preceding and succeeding spaces' do
        context 'when outside of quotes' do
          let(:query) { 'where a!=1' }
          it { should eq('where a != 1') }
        end

        context 'when inside of quotes' do
          let(:query) { 'select "a!=1"' }
          it { should eq(query) }
        end
      end
    end
  end

  context 'when handling comma' do
    context 'when it has no preceding space' do
      let(:query) { 'select a, b' }
      it { should eq(query) }
    end

    context 'when it has preceding space' do
      context 'when outside of quotes' do
        let(:query) { 'select a , b' }
        it { should eq('select a, b') }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a , b"' }
        it { should eq(query) }
      end
    end
  end

  context 'when handling semicolon' do
    context 'when it has no preceding space' do
      let(:query) { 'select a;' }
      it { should eq("select a\n;") }
    end

    context 'when it has preceding space' do
      context 'when outside of quotes' do
        let(:query) { 'select a ;' }
        it { should eq("select a\n;") }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a ;"' }
        it { should eq(query) }
      end
    end
  end

  context 'when handling slash-g' do
    context 'when it has no preceding space' do
      let(:query) { 'select a\\G' }
      it { should eq("select a\n\\G") }
    end

    context 'when it has preceding space' do
      context 'when outside of quotes' do
        let(:query) { 'select a \\G' }
        it { should eq("select a\n\\G") }
      end

      context 'when inside of quotes' do
        let(:query) { 'select "a \\G"' }
        it { should eq(query) }
      end
    end
  end

  context 'when handling keywords' do
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

    context 'when there are both primary and secondary keywords' do
      let(:query) { 'select * from a join b on a.id = b.id where a.id = 1 and a.id != 2 or a.id = 3 order by 1;' }
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
          ;
        SQL
      end
    end
  end

  context 'when handling parenthesis' do
    context 'when it creates new line' do
      context 'when there is one level' do
        let(:query) { 'select * from (select * from a); ' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from (
              select *
              from a
            )
            ;
          SQL
        end
      end

      context 'when there are two levels' do
        let(:query) { 'select * from (select * from (select * from a)); ' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from (
              select *
              from (
                select *
                from a
              )
            )
            ;
          SQL
        end
      end
    end

    context 'when it does not create new line' do
      context 'when handling function call' do
        let(:query) { 'select distinct(`group`) from sysconfig;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select distinct(`group`)
            from sysconfig
            ;
          SQL
        end
      end
    end
  end

  context 'when handling backtick, used to escape reserved words' do
    let(:query) { 'select a, `group`, b' }
    it { should eq(query) }
  end
end
