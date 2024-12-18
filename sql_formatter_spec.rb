require './sql_formatter'
require 'rspec'

RSpec.configure do |config|
  config.filter_run_when_matching :focus
end

describe SqlFormatter do
  let(:query) { '<overwrite me in examples>' }
  let(:formatter) { described_class.new(query) }
  before { formatter.run }
  subject { formatter.formatted }

  context 'when handling simple characters' do
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

    context 'when handling backtick' do
      let(:query) { 'select a, `group`, b' }
      it { should eq(query) }
    end

    context 'when handling new line' do
      let(:query) { "select\na\n,\n\nb" }
      it { should eq('select a, b') }
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

  context 'when handling parentheses' do
    context 'when handling a subquery list' do
      context 'when subquery comes after `from`' do
        context 'when nesting one level' do
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

        context 'when nesting two levels' do
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

      context 'when subquery comes after `in`' do
        let(:query) { 'select * from a where id in (select id from b);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where id in (
              select id
              from b
            )
            ;
          SQL
        end
      end

      context 'when subquery comes after `or <column> in`' do
        let(:query) { 'select * from a where id in (select id from b) or token in (select token from c);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where id in (
              select id
              from b
            ) or token in (
              select token
              from c
            )
            ;
          SQL
        end
      end
    end

    context 'when handling a non-subquery list' do
      context 'when list is short' do
        let(:query) { 'select * from a where id in (1,2,3,4);' }
        it { should eq("select *\nfrom a\nwhere id in (1, 2, 3, 4)\n;") }
      end

      context 'when list is long' do
        let(:query) { 'select * from a where id in (1111111111,2222222222,3333333333,4444444444);' }
        xit { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where id in (
              1111111111,
              2222222222,
              3333333333,
              4444444444
            )
            ;
          SQL
        end
      end
    end

    context 'when calling function' do
      context 'when calling one function' do
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

      context 'when calling two functions' do
        let(:query) { "select upper(concat('hello', ' ', 'world'));" }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select upper(concat('hello', ' ', 'world'))
            ;
          SQL
        end
      end
    end
  end

  context 'when handling keywords' do
    context 'when there is only primary keywords' do
      let(:query) { 'select a.id from a join b where b.id = 1 union select 1 id order by 1;' }
      it { should eq(expected) }

      let(:expected) do
        <<~SQL.chomp
          select a.id
          from a
          join b
          where b.id = 1
          union
          select 1 id
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

    context 'when handling long `select`' do
      context 'when long enough' do
        context 'when there is no alias' do
          let(:query) { 'select aaaaaaaaaa, bbbbbbbbbb, cccccccccc, dddddddddd;' }
          it { should eq(expected) }

          let(:expected) do
            <<~SQL.chomp
              select
                aaaaaaaaaa,
                bbbbbbbbbb,
                cccccccccc,
                dddddddddd
              ;
            SQL
          end
        end

        context 'when there is alias' do
          let(:query) { 'select aaaaaaaaaa as a, bbbbbbbbbb as b, cccccccccc as c, dddddddddd as d;' }
          it { should eq(expected) }

          let(:expected) do
            <<~SQL.chomp
              select
                aaaaaaaaaa as a,
                bbbbbbbbbb as b,
                cccccccccc as c,
                dddddddddd as d
              ;
            SQL
          end
        end
      end

      context 'when not enough chars' do
        let(:query) { 'select a, b, c, d;' }
        it { should eq("select a, b, c, d\n;") }
      end

      context 'when not enough commas' do
        let(:query) { 'select aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;' }
        it { should eq("select aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n;") }
      end
    end

    context 'when handling upper case keywords' do
      let(:query) { 'SELECT 1 FROM A;' }
      it { should eq(expected) }

      let(:expected) do
        <<~SQL.chomp
          select 1
          from A
          ;
        SQL
      end
    end

    context 'when handling multi-word join' do
      context 'when left join' do
        let(:query) { 'select a.id from a left join b;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select a.id
            from a
            left join b
            ;
          SQL
        end
      end

      context 'when full outer join' do
        let(:query) { 'select a.id from a full outer join b;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select a.id
            from a
            full outer join b
            ;
          SQL
        end
      end
    end
  end
end
