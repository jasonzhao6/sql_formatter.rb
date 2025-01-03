require_relative 'sql_formatter'
require 'rspec'

RSpec.configure do |config|
  config.filter_run_when_matching :focus
end

describe SqlFormatter do
  let(:query) { '<overwrite me in examples>' }
  let(:formatter) { described_class.new(query) }
  before { formatter.run }
  subject { formatter.formatted }

  context 'when handling characters' do
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
      context 'when it does not have preceding space' do
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
      context 'when it does not have preceding space' do
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
      context 'when it does not have preceding space' do
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

    context 'when handling one-char operator' do
      context 'when it has preceding and succeeding spaces' do
        let(:query) { 'where a = 1' }
        it { should eq(query) }
      end

      context 'when it does not have preceding and succeeding spaces' do
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

    context 'when handling two-char operator' do
      context 'when it has preceding and succeeding spaces' do
        let(:query) { 'where a != 1' }
        it { should eq(query) }
      end

      context 'when it does not have preceding and succeeding spaces' do
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

    context 'when handling backtick' do
      let(:query) { 'select a, `group`, b' }
      it { should eq(query) }
    end

    context 'when handling new line' do
      let(:query) { "select\na\n,\n\nb" }
      it { should eq('select a, b') }
    end
  end

  context 'when handling parenthesis' do
    context 'when enclosing a subquery' do
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
            )
            or token in (
              select token
              from c
            )
            ;
          SQL
        end
      end
    end

    context 'when enclosing a list' do
      context 'when list is short' do
        let(:query) { 'select * from a where id in (1,2,3,4);' }
        it { should eq("select *\nfrom a\nwhere id in (1, 2, 3, 4)\n;") }
      end

      context 'when list is long' do
        let(:query) { 'select * from a where id in (1111111111,2222222222);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where id in (
              1111111111,
              2222222222
            )
            ;
          SQL
        end
      end
    end

    context 'when enclosing compound conditions' do
      context 'when it comes after `where`' do
        let(:query) { 'select * from a where (a = 1 and b = 2) or c = 3;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where (
              a = 1
              and b = 2
            )
            or c = 3
            ;
          SQL
        end
      end

      context 'when it comes after `and`' do
        let(:query) { 'select * from a where a = 1 and (b = 2 or c = 3);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where a = 1
            and (
              b = 2
              or c = 3
            )
            ;
          SQL
        end
      end

      context 'when it comes after `or`' do
        let(:query) { 'select * from a where a = 1 or (b = 2 and c = 3);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where a = 1
            or (
              b = 2
              and c = 3
            )
            ;
          SQL
        end
      end

      context 'when it comes twice' do
        let(:query) { 'select * from a where a = 1 or (b = 2 and c = 3) or (d = 4 and e = 5);' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where a = 1
            or (
              b = 2
              and c = 3
            )
            or (
              d = 4
              and e = 5
            )
            ;
          SQL
        end
      end

      context 'when it comes nested' do
        let(:query) { 'select * from a where a = 1 or ((b = 2 or c = 3) and (d = 4 or e = 5));' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select *
            from a
            where a = 1
            or (
              (
                b = 2
                or c = 3
              )
              and (
                d = 4
                or e = 5
              )
            )
            ;
          SQL
        end
      end
    end

    context 'when calling a function' do
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

      context 'when calling nested functions' do
        let(:query) { "select upper(concat('hello', '-', 'world'));" }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select upper(concat('hello', '-', 'world'))
            ;
          SQL
        end
      end
    end
  end

  context 'when handling keywords' do
    context 'when handling keywords that get their own line' do
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
          let(:query) { 'select aaaaaaaaaa, bbbbbbbbbb;' }
          it { should eq(expected) }

          let(:expected) do
            <<~SQL.chomp
              select
                aaaaaaaaaa,
                bbbbbbbbbb
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

    context 'when handling uppercase keywords' do
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

    context 'when handling multiple joins' do
      context 'when there are consecutive joins' do
        let(:query) { 'select a.id from a left join b on a.id = b.id left join c on a.id = c.id;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select a.id

            from a

            left join b
            on a.id = b.id

            left join c
            on a.id = c.id

            ;
          SQL
        end
      end

      context 'when there are nested single joins' do
        let(:query) { 'select a.id from ( select c.id from c left join d on c.id = d.id ) left join b on a.id = b.id ;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select a.id
            from (
              select c.id
              from c
              left join d
              on c.id = d.id
            )
            left join b
            on a.id = b.id
            ;
          SQL
        end
      end

      context 'when there are nested consecutive joins' do
        let(:query) { 'select a.id from ( select d.id from d left join e on d.id = e.id left join f on d.id = f.id ) left join b on a.id = b.id left join c on a.id = c.id ;' }
        it { should eq(expected) }

        let(:expected) do
          <<~SQL.chomp
            select a.id

            from (
              select d.id

              from d

              left join e
              on d.id = e.id

              left join f
              on d.id = f.id
            )

            left join b
            on a.id = b.id

            left join c
            on a.id = c.id

            ;
          SQL
        end
      end
    end
  end
end
