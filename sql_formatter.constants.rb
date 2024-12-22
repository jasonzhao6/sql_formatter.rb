module Constants
  # Config: Whitespace
  SPACE  = ' '
  INDENT = '  '
  NEW_LINE = "\n"

  # Config: Break long comma-separated value (CSV) into multiple lines, e.g
  #   ```
  #   select         # Break long CSV after `SELECT`
  #     aaaaaaaaaa,
  #     bbbbbbbbbb
  #   ...
  #   where id in (  # Break long CSV after `PAREN_OPEN`
  #     1111111111,
  #     2222222222,
  #     3333333333,
  #     4444444444
  #   ```
  CHAR_MIN = 20
  COMMA_MIN = 1 # Note: N `COMMA` means N + 1 items

  # Config: Append with extra `NEW_LINE` in case of multiple `JOIN`, e.g
  #   ```
  #   select *
  #
  #   from a          # ^ Extra `NEW_LINE`
  #
  #   join b          # ^ Extra `NEW_LINE`
  #   on a.id = b.id
  #
  #   join c          # ^ Extra `NEW_LINE`
  #   on b.id = c.id
  #
  #   where c.id = 1  # ^ Extra `NEW_LINE`
  #
  #   ;               # ^ Extra `NEW_LINE`
  #   ```
  JOIN_MIN = 2

  # Individually referenced chars
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >) # Allowed to combine, e.g `!=`
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")
  SEMICOLON = ';'
  SLASH_G = ESCAPE + 'G' # Not singular by definition

  # `SINGULAR_CHARS` share a simple tokenization logic
  SINGULAR_CHARS = OPERATORS + %W(
    #{COMMA} #{SEMICOLON} #{PAREN_OPEN} #{PAREN_CLOSE}
  )

  # Individually referenced keywords
  SELECT = 'select'
  FROM = 'from'
  JOIN = 'join'
  WHERE = 'where'
  AND = 'and'
  OR = 'or'

  # Allow `PAREN_ABLE_KEYWORDS` to be followed by parenthesis, e.g
  #   ```
  #   where (       # Followed by compound conditions
  #     a = 1
  #     and b = 2
  #   ) or id in (  # Followed by subquery
  #     select id
  #     from b
  #   ) or id in (  # Followed by list
  #     1111111111,
  #     2222222222,
  #     3333333333,
  #     4444444444
  #   ```
  CONDITIONAL_KEYWORDS = %W(#{WHERE} #{AND} #{OR} #{PAREN_OPEN})
  QUARY_ABLE_KEYWORDS = %W(#{FROM} in) # Could be followed subquery or list
  PAREN_ABLE_KEYWORDS = CONDITIONAL_KEYWORDS + QUARY_ABLE_KEYWORDS

  # Allow `JOIN_KEYWORDS` to combine, e.g `left join`
  JOIN_KEYWORDS = %W(inner left right full outer #{JOIN})

  # Append `NEW_LINES_KEYWORDS` with extra `NEW_LINE` in case of multiple `JOIN`
  NEW_LINES_KEYWORDS = JOIN_KEYWORDS + %W(
    #{SELECT} #{FROM} #{WHERE} order union #{SEMICOLON} #{SLASH_G}
  )

  # Append `NEW_LINE_KEYWORDS` with `NEW_LINE`
  NEW_LINE_KEYWORDS = NEW_LINES_KEYWORDS + %W(#{AND} #{OR} on)

  # Collect all keywords here
  # Reminder: Update this when updating any `*_KEYWORDS` constants above
  ALL_KEYWORDS = NEW_LINE_KEYWORDS + %w(in)
end
