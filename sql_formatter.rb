require 'byebug'

# Fields
# - token: The word preceding `PAREN_OPEN`
# - is_subquery: The value following `PAREN_OPEN` is a subquery
# - is_long_list: The value following `PAREN_OPEN` is a long list of values
# - is_short_list: The value following `PAREN_OPEN` is a short list of values
Parenthesis = Struct.new(:token, :is_subquery, :is_long_list, :is_short_list)

class SqlFormatter
  # Characters
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")
  SEMICOLON = ';'
  SLASH_G = ESCAPE + 'G'

  # Whitespace
  INDENT = '  '
  NEW_LINE = "\n"

  # Keywords
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
  #   where id in (  # Break long CSV `IN` parenthesis
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
  #   from (       # Followed by subquery
  #     select *
  #     from a
  #   )
  #   where (      # Followed by compound conditions
  #     a = 1
  #     and b = 2
  #   ) or (
  #     c = 3
  #     and d = 4
  #   )
  #   ```
  PAREN_ABLE_KEYWORDS = %W(#{FROM} #{WHERE} #{AND} #{OR} in)

  # Allow `JOIN_KEYWORDS` to combine, e.g `left join`
  JOIN_KEYWORDS = %w(inner left right full outer join)

  # Give `NEW_LINE_KEYWORDS` their own line
  NEW_LINE_KEYWORDS = JOIN_KEYWORDS + %W(
    #{SELECT} #{FROM} #{WHERE} order union #{SEMICOLON} #{SLASH_G}
    #{AND} #{OR} on
  )

  # Downcase all keywords
  DOWNCASE_ALL_KEYWORDS = NEW_LINE_KEYWORDS + %w(in)

  attr_reader :tokens
  attr_reader :formatted

  def initialize(query)
    # Props
    @query = query

    # States
    @tokens = nil
    @formatted = nil
  end

  def run
    @tokens = tokenize(@query)
    @formatted = format(@tokens)
  end

  private

  def tokenize(query)
    tokens = [] # Return value

    # Accumulate chars into `buffer` until the next flush event
    # When flushing a quoted value, flush it as a one token
    # When flushing a non-quoted value, split it on whitespace
    # Flush happens when opening/closing a quote and upon special characters
    buffer = ''

    # Track when we open/close a quote
    open_quote = nil # Valid states: %w(nil ' ")

    # REMINDER: Avoid nested `if` statements; keep it one level for simplicity
    chars = query.chars
    chars.each.with_index do |char, index|
      last_char = chars[index - 1]

      # Handle when switching from a quoted value to a non-quoted value
      if QUOTES.include?(char) && ESCAPE != last_char && open_quote == char
        open_quote = nil

        buffer << char
        tokens << buffer
        buffer = ''

      # Handle when switching from a non-quoted value to a quoted value
      elsif QUOTES.include?(char) && ESCAPE != last_char && open_quote.nil?
        open_quote = char

        tokens.concat(split_and_downcase(buffer))
        buffer = '' << char

      # Treat operator as its own token
      elsif OPERATORS.include?(char) &&
        !OPERATORS.include?(last_char) &&
        open_quote.nil?

        tokens.concat(split_and_downcase(buffer))
        tokens << char
        buffer = ''

      # Pair up consecutive operators; they are always either 1-char or 2-chars
      elsif OPERATORS.include?(char) &&
        OPERATORS.include?(last_char) &&
        open_quote.nil?

        tokens.last << char

      # Treat comma and semicolon as their own tokens
      elsif (COMMA == char || SEMICOLON == char) && open_quote.nil?
        tokens.concat(split_and_downcase(buffer))
        tokens << char
        buffer = ''

      # Treat slash-g as its own token
      elsif 'G' == char && ESCAPE == last_char && open_quote.nil?
        tokens.concat(split_and_downcase(buffer.chop))
        tokens << SLASH_G
        buffer = ''

      # Treat parenthesis as their own tokens
      elsif (PAREN_OPEN == char || PAREN_CLOSE == char) && open_quote.nil?
        tokens.concat(split_and_downcase(buffer))
        tokens << char
        buffer = ''

      # Accumulate non-special characters until the next flush event
      else
        buffer << char
      end
    end

    # Final flush
    tokens.concat(split_and_downcase(buffer))

    tokens
  end

  def split_and_downcase(buffer)
    buffer.split.map do |token|
      (DOWNCASE_ALL_KEYWORDS.include?(token.downcase) ? token.downcase : token)
    end
  end

  def format(tokens)
    formatted = '' # Return value

    # Break long comma-separated value (CSV) into multiple lines
    is_long_select = false # Break long CSV after `SELECT`
    is_long_list = false # Break long CSV `IN` parenthesis
    add_new_line = false # Add a `NEW_LINE` immediately; then after each `COMMA`

    # Track where we are in the parenthesis stack to add appropriate whitespace
    paren_stack = [] # An array of `Parenthesis` struct

    # REMINDER: Avoid nested `if` statements; keep it one level for simplicity
    tokens.each.with_index do |token, index|
      last_token = tokens[index - 1]
      indent_level = paren_stack.select(&:is_subquery).size

      # Break long CSV into multiple lines
      if (is_long_select || paren_stack.last&.is_long_list) &&
        (add_new_line || COMMA == last_token)

        add_new_line = false
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token

      # Append `COMMA` without space
      elsif COMMA == token
        formatted << token

      # Append `PAREN_OPEN` with space when preceded by `PAREN_ABLE_KEYWORDS`
      elsif PAREN_OPEN == token && PAREN_ABLE_KEYWORDS.include?(last_token)
        formatted << ' ' << token

      # Append `PAREN_OPEN` without space when preceded by a function call(?)
      elsif PAREN_OPEN == token
        formatted << token

      # Append after `PAREN_OPEN` without space when it's a short list
      elsif PAREN_OPEN == last_token && paren_stack.last.is_short_list
        formatted << token

      # Append after `PAREN_OPEN` without space when it's a function arg(?)
      elsif PAREN_OPEN == last_token && !paren_stack.last.is_subquery
        formatted << token

      # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a subquery
      elsif PAREN_CLOSE == token && paren_stack.last.is_subquery
        formatted << NEW_LINE << INDENT * (indent_level - 1) << token

      # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a long list
      elsif PAREN_CLOSE == token && paren_stack.last.is_long_list
        formatted << NEW_LINE << INDENT * indent_level << token

      # Append `PAREN_CLOSE` without space when preceded by a short list
      elsif PAREN_CLOSE == token && paren_stack.last.is_short_list
        formatted << token

      # Append `PAREN_CLOSE` without space when preceded by a function call(?)
      elsif PAREN_CLOSE == token
        formatted << token

      # Combine `JOIN_KEYWORDS` with space
      elsif JOIN_KEYWORDS.include?(token) && JOIN_KEYWORDS.include?(last_token)
        formatted << ' ' << token

      # Append `NEW_LINE_KEYWORDS` with `NEW_LINE`
      elsif NEW_LINE_KEYWORDS.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token

      # Append everything else with space
      else
        formatted << ' ' << token
      end

      # Decide if we are breaking long CSV into mulitple lines
      # And track where we are in the parenthesis stack
      case tokens[index]
      when SELECT
        is_long_select = add_new_line = is_long_csv?(tokens, index)
      when FROM
        is_long_select = false
      when PAREN_OPEN
        parenthesis = Parenthesis.new(tokens[index - 1])
        parenthesis.is_subquery = SELECT == tokens[index + 1]
        parenthesis.is_long_list = add_new_line = is_long_csv?(tokens, index)
        parenthesis.is_short_list = (
          !parenthesis.is_subquery && !parenthesis.is_long_list
        )

        paren_stack.push(parenthesis)
      when PAREN_CLOSE
        paren_stack.pop
      end
    end

    formatted.strip
  end

  def is_long_csv?(tokens, index)
    char_count = 0
    comma_count = 0
    paren_count = 0

    # Count ahead
    ((index + 1)...tokens.size).each do |next_index|
      # To decide `is_long_select`, count until the next `FROM`
      break if FROM == tokens[next_index]
      # To decide `is_long_list`, count until the matching `PAREN_CLOSE`
      break if paren_count < 0

      # Keep track of nested parenthesis and ignore any enclosed `COMMA`
      case tokens[next_index]
      when PAREN_OPEN then paren_count += 1
      when PAREN_CLOSE then paren_count -= 1
      end

      case tokens[next_index]
      when COMMA then comma_count += 1 if paren_count == 0 # Count `COMMA`
      else char_count += tokens[next_index].size # Count chars
      end
    end

    # Compare counts to the limits
    char_count >= CHAR_LIMIT && comma_count >= COMMA_LIMIT
  end
end

# If running specs, do not expect CLI input
return if ARGV.first&.end_with?('sql_formatter_spec.rb')

# In case of arg mode
input = ARGV.join(' ')

# In case of interactive mode
if ARGV.empty?
  puts 'Enter a sql query (formatting starts after `;` or `\\G`):'
  puts
  puts

  loop do
    input << gets
    break if input.strip.end_with?(';') || input.strip.end_with?('\\G')
  rescue TypeError
    raise 'CLI input is required!'
  end

  puts
  puts
  puts '>>>>>>'
end

# Process input
formatter = SqlFormatter.new(input)
formatter.run

# Print output
puts
puts
puts formatter.formatted
puts
