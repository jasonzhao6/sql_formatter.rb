module Constants
  # Whitespace to be added by `#format`
  INDENT = '  '
  NEW_LINE = "\n"

  # Characters to be individually referenced
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")
  SEMICOLON = ';'
  SLASH_G = ESCAPE + 'G'

  # Tokenize `SIMPLE_CHARS` as-is
  SIMPLE_CHARS = OPERATORS + %W(
    #{COMMA} #{SEMICOLON} #{PAREN_OPEN} #{PAREN_CLOSE}
  )

  # Keywords to be individually referenced
  SELECT = 'select'
  FROM = 'from'
  WHERE = 'where'
  AND = 'and'
  OR = 'or'

  # Break long comma-separated value (CSV) into multiple lines, e.g
  #   ```
  #   select         # Break long CSV after `SELECT`
  #     aaaaaaaaaa,
  #     bbbbbbbbbb
  #   from a
  #   where id in (  # Break long CSV after `PAREN_OPEN`
  #     1111111111,
  #     2222222222,
  #     3333333333,
  #     4444444444
  #   )
  #   ```
  CHAR_LIMIT = 20
  COMMA_LIMIT = 1

  # Allow `PAREN_ABLE_KEYWORDS` to be followed by parenthesis, e.g
  #   ```
  #   select *
  #   from a
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
  #   )
  #   ```
  CONDITIONAL_KEYWORDS = %W(#{WHERE} #{AND} #{OR} #{PAREN_OPEN})
  QUARY_ABLE_KEYWORDS = %W(#{FROM} in) # Followed by subquery or list
  PAREN_ABLE_KEYWORDS = CONDITIONAL_KEYWORDS + QUARY_ABLE_KEYWORDS

  # Allow `JOIN_KEYWORDS` to combine, e.g `left join`
  JOIN_KEYWORDS = %w(inner left right full outer join)

  # Give `NEW_LINE_KEYWORDS` their own line
  NEW_LINE_KEYWORDS = JOIN_KEYWORDS + %W(
    #{SELECT} #{FROM} #{WHERE} order union #{SEMICOLON} #{SLASH_G}
    #{AND} #{OR} on
  )

  # Downcase all keywords
  DOWNCASE_ALL_KEYWORDS = NEW_LINE_KEYWORDS + %w(in)
end
