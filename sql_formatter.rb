class SqlFormatter
  # Characters with simple tokenization logic
  COMMA = ','
  ESCAPE = '\\'
  SEMICOLON = ';'
  SLASH_G = ESCAPE + 'G'

  # Characters with complex tokenization logic
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")

  # Formatting config
  INDENT = '  '
  NEW_LINE = "\n"

  # Break long `SELECT` into multiple lines if over char and comma limits
  FROM = 'from'
  SELECT = 'select'
  SELECT_CHAR_LIMIT = 20
  SELECT_COMMA_LIMIT = 1

  # Indent secondary keywords an extra level than primary keywords, e.g
  #  ```
  #  from a            # `from` is a primary keyword
  #  left join b       # `left join` is a primary keyword
  #    on a.id = b.id  # `on` is a secondary keyword
  #  where key1 = 1    # `where` is a primary keyword
  #    and key2 = 2    # `and` is a secondary keyword
  #  ```
  JOIN_KEYWORDS = %w(inner left right full outer join) # Can be multi-word
  PRIMARY_KEYWORDS = JOIN_KEYWORDS +
    %W(select from where order union #{SEMICOLON} #{SLASH_G})
  AND_OR_KEYWORDS = %w(and or)
  SECONDARY_KEYWORDS = AND_OR_KEYWORDS + %w(on)

  # Add a level of indentation for each subquery
  SUBQUERY_KEYWORDS = %w(from in)
  NOT_SUBQUERY = '<not subquery>'

  # Downcase all keywords
  ALL_KEYWORDS =
    (PRIMARY_KEYWORDS + SECONDARY_KEYWORDS + SUBQUERY_KEYWORDS).uniq

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

    # Remember the last character, which can influence the next one's handling
    last_char = nil

    # Keep track of open quote and treat the entire quoted value as one token
    open_quote = nil # Valid states: %w(nil ' ")

    # Holds a quoted value until the next non-quoted value, and vice versa
    # When switching between the two, flush and process as follows:
    # - The entirety of a quoted value is treated as a whole token
    # - Non-quoted values are tokenized by splitting on whitespace
    # Flush also happens after `OPERATORS`, `COMMA`, `SLASH_G`, etc
    buffer = ''

    # Accumulate `char` in `buffer`, then flush `buffer` to `tokens`
    # REMINDER: Avoid nested conditionals; keep it only one level for simplicity
    query.chars.each do |char|
      # Handle when switching from a quoted value to a non-quoted value
      if QUOTES.include?(char) && ESCAPE != last_char && open_quote == char
        open_quote = nil

        buffer << char
        tokens << buffer
        buffer = ''

      # Handle when switching from a non-quoted value to a quoted value
      elsif QUOTES.include?(char) && ESCAPE != last_char && open_quote.nil?
        open_quote = char

        concat_downcased_buffer(tokens, buffer)
        buffer = '' << char

      # Treat operator as its own token
      elsif OPERATORS.include?(char) && !OPERATORS.include?(last_char) && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Pair up consecutive operators; they are always either 1-char or 2-chars
      elsif OPERATORS.include?(char) && OPERATORS.include?(last_char) && open_quote.nil?
        tokens.last << char

      # Treat comma and semicolon as their own tokens
      elsif (COMMA == char || SEMICOLON == char) && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Treat slash-g as its own token
      elsif 'G' == char && ESCAPE == last_char && open_quote.nil?
        tokens.concat(buffer.chop.split)
        tokens << SLASH_G
        buffer = ''

      # Treat open and close parentheses as their own tokens
      elsif (PAREN_OPEN == char || PAREN_CLOSE == char) && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Accumulate in buffer and wait for the next flush
      else
        buffer << char
      end

      # Remember the last character, which can influence the next one's handling
      last_char = char
    end

    # Final flush
    concat_downcased_buffer(tokens, buffer)

    tokens
  end

  def concat_downcased_buffer(tokens, buffer)
    buffer.split.each do |token|
      tokens << (ALL_KEYWORDS.include?(token.downcase) ? token.downcase : token)
    end
  end

  def format(tokens)
    formatted = '' # Return value

    # Remember the last token, which can influence the next one's handling
    last_token = nil

    # States for handling parentheses
    paren_stack = [] # Push after `PAREN_OPEN`; pop after `PAREN_CLOSE`
    indent_level = 0 # Inc after `PAREN_OPEN`; dec before `PAREN_CLOSE`

    # States for handling long `SELECT`
    one_column_per_line = false
    is_new_column = false

    # Add formatted `token` to the return value
    # REMINDER: Avoid nested conditionals; keep it only one level for simplicity
    tokens.each.with_index do |token, index|
      # Break long `SELECT` into multiple lines
      if one_column_per_line && is_new_column
        is_new_column = false
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token

      # Add `COMMA` without space
      elsif COMMA == token
        is_new_column = true # Only used when handling long `SELECT`
        formatted << token

      # Add `PAREN_OPEN` with a space when enclosing a list
      elsif PAREN_OPEN == token && SUBQUERY_KEYWORDS.include?(last_token)
        indent_level += 1 # Only used when parentheses encloses a subquery
        formatted << ' ' << token

      # Add `PAREN_OPEN` without space (when preceded by a function)
      elsif PAREN_OPEN == token && !SUBQUERY_KEYWORDS.include?(last_token)
        formatted << token

      # Add token after `PAREN_OPEN` without space (when preceded by a function)
      elsif PAREN_OPEN == last_token && !SUBQUERY_KEYWORDS.include?(paren_stack.last)
        formatted << token

      # Add token after `PAREN_OPEN` without space enclosing a non-subquery list
      elsif PAREN_OPEN == last_token &&
        SUBQUERY_KEYWORDS.include?(paren_stack.last) &&
        SELECT != token

        paren_stack[-1] = NOT_SUBQUERY
        formatted << token

      # Add `PAREN_CLOSE` with a new line when enclosing a subquery list
      elsif PAREN_CLOSE == token && SUBQUERY_KEYWORDS.include?(paren_stack.last)
        indent_level -= 1 # Only used when parentheses encloses a subquery
        formatted << NEW_LINE << INDENT * indent_level << token

      # Add `PAREN_CLOSE` without space when enclosing a non-subquery list
      elsif PAREN_CLOSE == token && NOT_SUBQUERY == paren_stack.last
        indent_level -= 1 # Only used when parentheses encloses a subquery
        formatted << token

      # Add `PAREN_CLOSE` without space (when preceded by a function)
      elsif PAREN_CLOSE == token &&
        !SUBQUERY_KEYWORDS.include?(paren_stack.last)

        formatted << token

      # Add `AND_OR_KEYWORDS` with a space when preceded by `PAREN_CLOSE`
      elsif PAREN_CLOSE == last_token && AND_OR_KEYWORDS.include?(token)
        formatted << ' ' << token

      # Add consecutive `JOIN_KEYWORDS` with a space
      elsif JOIN_KEYWORDS.include?(token) && JOIN_KEYWORDS.include?(last_token)
        formatted << ' ' << token

      # Add `PRIMARY_KEYWORDS` with normal indentation
      elsif PRIMARY_KEYWORDS.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token

      # Add `SECONDARY_KEYWORDS` with an extra level of indentation
      elsif SECONDARY_KEYWORDS.include?(token)
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token

      # Add anything else with a space
      else
        formatted << ' ' << token
      end

      # Set states for handling parentheses
      update_paren_stack(paren_stack, token, last_token)

      # Set states for handling long `SELECT`
      case is_long_select(tokens, index)
      when true then one_column_per_line = is_new_column = true
      when false then one_column_per_line = false
      end

      # Remember the last token, which can influence the next one's handling
      last_token = token
    end

    formatted.strip
  end

  def update_paren_stack(paren_stack, token, last_token)
    case token
    when PAREN_OPEN then paren_stack.push(last_token)
    when PAREN_CLOSE then paren_stack.pop
    end
  end

  def is_long_select(tokens, index)
    return false if FROM == tokens[index] # Deactivate long `select` handling
    return nil if SELECT != tokens[index] # Continue with the current handling

    char_count = 0
    comma_count = 0
    paren_count = 0

    # Count chars and commas
    ((index + 1)...tokens.size).each do |next_index|
      case tokens[next_index]
      # Stop when we reach the next `FROM`
      when FROM then break
      # Count only `COMMA` outside of parentheses
      when PAREN_OPEN then paren_count += 1
      when PAREN_CLOSE then paren_count -= 1
      when COMMA then comma_count += 1 if paren_count == 0
      # Count all chars (unintentionally ignoring whitespace)
      else char_count += tokens[next_index].size
      end
    end

    # Activate long `select` handling if over char and comma limits
    char_count >= SELECT_CHAR_LIMIT && comma_count >= SELECT_COMMA_LIMIT
  end
end

# If running from specs, stop here
return if ARGV.first&.end_with?('sql_formatter_spec.rb')

# Otherwise, process CLI input
input = ARGV.join(' ')

# If no argument, enter into interactive mode
if ARGV.empty?
  puts 'Enter a sql query (formatting starts after `;` or `\\G`):'
  puts
  puts

  loop do
    input << gets
    break if input.strip.end_with?(';') || input.strip.end_with?('\\G')
  rescue TypeError
    raise 'Either an argument or interactive input is required.'
  end

  puts
  puts
  puts '>>>>>>'
end

formatter = SqlFormatter.new(input)
formatter.run

puts
puts
puts formatter.formatted
puts
