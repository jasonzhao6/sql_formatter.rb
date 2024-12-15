class SqlFormatter
  # Characters with special tokenizing logic
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")
  SEMICOLON = ';'
  SLASH_G = '\\G'

  # Keywords with special formatting logic
  SELECT = 'select'
  FROM = 'from'

  # Formatting configurations
  INDENT = '  '
  NEW_LINE = "\n"
  SELECT_COMMA_LIMIT = 3 # Break `select` into multiple lines if over limit

  # When formatting, indent secondary keywords an extra level than primary, e.g
  #  ```
  #  from a            # `from` is a primary keyword
  #  left join b       # `left join` is a primary phrase
  #    on a.id = b.id  # `on` is a secondary keyword
  #  where key1 = 1    # `where` is a primary keyword
  #    and key2 = 2    # `and` is a secondary keyword
  #  ```
  JOIN_KEYWORDS = %w(inner left right full outer join) # Can form phrases
  PRIMARY_KEYWORDS = JOIN_KEYWORDS +
    %W(select from where order union #{SEMICOLON} #{SLASH_G})
  SECONDARY_KEYWORDS = %w(on and or)

  # When formatting, if these keywords precede `PAREN_OPEN`, update indent level
  INDENT_KEYWORDS = %w(from in)

  # When tokenizing, downcase all keywords
  ALL_KEYWORDS = (PRIMARY_KEYWORDS + SECONDARY_KEYWORDS + INDENT_KEYWORDS).uniq

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

    # Holds a non-quoted value until the next quoted value, and vice versa
    # When switching between the two, flush and process as follows:
    # - Non-quoted values are tokenized by splitting on whitespace
    # - The entirety of a quoted value is treated as a whole token
    # Flush also happens after `OPERATORS`, `COMMA`, `SLASH_G`, etc
    buffer = ''

    # Accumulate `char` in `buffer`, then flush `buffer` to `tokens`
    query.chars.each do |char|
      # Handle when switching from a non-quoted value to a quoted value
      if QUOTES.include?(char) && ESCAPE != last_char && open_quote.nil?
        open_quote = char

        concat_downcased_buffer(tokens, buffer)
        buffer = '' << char

      # Handle when switching from a quoted value to a non-quoted value
      elsif QUOTES.include?(char) && ESCAPE != last_char && open_quote == char
        open_quote = nil

        buffer << char
        tokens << buffer
        buffer = ''

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
    paren_stack = [] # Push after `(`; pop after `)`
    indent_level = 0 # Increment after `(`; decrement before `)`
    skip_space_after_open_paren = false

    # States for handling long `select`
    one_column_per_line = false
    is_new_column = false

    # Add formatted `token` to the return value
    tokens.each.with_index do |token, index|
      if skip_space_after_open_paren
        skip_space_after_open_paren = false
        formatted << token
      elsif one_column_per_line && is_new_column
        is_new_column = false
        formatted << token
      elsif COMMA == token && one_column_per_line
        is_new_column = true
        formatted << token << NEW_LINE << INDENT * (indent_level + 1)
      elsif COMMA == token && !one_column_per_line
        formatted << token
      elsif PAREN_OPEN == token && INDENT_KEYWORDS.include?(last_token)
        indent_level += 1
        formatted << ' ' << token
      elsif PAREN_OPEN == token && !INDENT_KEYWORDS.include?(last_token)
        skip_space_after_open_paren = true
        formatted << token
      elsif PAREN_CLOSE == token && INDENT_KEYWORDS.include?(paren_stack.last)
        indent_level -= 1
        formatted << NEW_LINE << INDENT * indent_level << token
      elsif PAREN_CLOSE == token && !INDENT_KEYWORDS.include?(paren_stack.last)
        formatted << token
      elsif JOIN_KEYWORDS.include?(token) && JOIN_KEYWORDS.include?(last_token)
        formatted << ' ' << token
      elsif PRIMARY_KEYWORDS.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token
      elsif SECONDARY_KEYWORDS.include?(token)
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token
      else
        formatted << ' ' << token
      end

      # Set states for handling parentheses
      case token
      when PAREN_OPEN then paren_stack.push(last_token)
      when PAREN_CLOSE then paren_stack.pop
      end

      # Set states for handling long `select`
      case token
      when SELECT
        comma_count = 0
        (index...tokens.size).each do |next_index|
          comma_count += 1 if COMMA == tokens[next_index]
          break if FROM == tokens[next_index]
        end

        if comma_count >= SELECT_COMMA_LIMIT
          one_column_per_line = true
          is_new_column = true
          formatted << NEW_LINE << INDENT * (indent_level + 1)
        end
      when FROM then one_column_per_line = false
      end

      # Remember the last token, which can influence the next one's handling
      last_token = token
    end

    formatted.strip
  end
end

# If running specs, stop here
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
