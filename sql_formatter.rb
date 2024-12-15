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

  # When formatting, indent secondary keywords an extra time than primary, e.g
  #  ```
  #  from a            # `from` is a primary keyword
  #  join b            # `join` is a primary keyword
  #    on a.id = b.id  # `on` is a secondary keyword
  #  where key1 = 1    # `where` is a primary keyword
  #    and key2 = 2    # `and` is a secondary keyword
  #  ```
  KEYWORDS_PRIMARY = %W(
    select from join where order #{SEMICOLON} #{SLASH_G} #{PAREN_CLOSE}
  )
  KEYWORDS_SECONDARY = %w(on and or)

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

    # Keep track of an open quote and treat the entire quoted value as one token
    open_quote = nil # Valid states: %w(nil ' ")

    # These characters influence how the next character will be handled
    was_escape = false # Escapes the next character
    was_operator = false # Pair up consecutive operators, e.g `!=`

    # Holds either a non-quoted value until the next quoted value or vice versa
    # When switching between the two, the buffer is flushed and process like so:
    # - Non-quoted values are tokenized by splitting on whitespace
    # - The entirety of a quoted value is treated as a whole token
    buffer = ''

    query.chars.each do |char|
      # Handle when switching from a non-quoted value to a quoted value
      if QUOTES.include?(char) && !was_escape && open_quote.nil?
        open_quote = char

        concat_downcased_buffer(tokens, buffer)
        buffer = '' << char

      # Handle when switching from a quoted value to a non-quoted value
      elsif QUOTES.include?(char) && !was_escape && open_quote == char
        open_quote = nil

        buffer << char
        tokens << buffer
        buffer = ''

      # Treat operator as its own tokens
      elsif OPERATORS.include?(char) && !was_operator && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Pair up consecutive operators; they are always either 1-char or 2-chars
      elsif OPERATORS.include?(char) && was_operator && open_quote.nil?
        tokens.last << char

      # Treat comma and semicolon as their own tokens
      elsif (COMMA == char || SEMICOLON == char) && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Treat slash-g as its own token
      elsif 'G' == char && was_escape && open_quote.nil?
        tokens.concat(buffer.chop.split)
        tokens << SLASH_G
        buffer = ''

      # Treat open and close parentheses as their own tokens
      elsif (PAREN_OPEN == char || PAREN_CLOSE == char) && open_quote.nil?
        concat_downcased_buffer(tokens, buffer)
        tokens << char
        buffer = ''

      # Add to buffer and wait for the next flush
      else
        buffer << char
      end

      # Remember characters that influence the next character's handling
      was_escape = ESCAPE == char
      was_operator = OPERATORS.include?(char)
    end

    # Final flush
    concat_downcased_buffer(tokens, buffer)
  end

  def concat_downcased_buffer(tokens, buffer)
    tokens.concat(buffer.downcase.split)
  end

  def format(tokens)
    formatted = '' # Return value

    # States for parenthesis handling
    indent_level = 0 # Increments after `(`; decrements before `)`
    paren_stack = [] # Push after `(`; pop after `)`
    last_keyword = nil
    skip_next_space = false

    # States for long `select` handling
    is_long_select = false
    is_new_column = false

    tokens.each.with_index do |token, index|
      indent_level -= 1 if PAREN_CLOSE == token && (KEYWORDS_PRIMARY.include?(paren_stack.last) || KEYWORDS_SECONDARY.include?(paren_stack.last))

      # Add `token` to formatted return value
      if skip_next_space
        skip_next_space = false
        formatted << token
      elsif is_long_select && is_new_column
        is_new_column = false
        formatted << token
      elsif COMMA == token && !is_long_select
        formatted << token
      elsif COMMA == token && is_long_select
        is_new_column = true
        formatted << token << NEW_LINE << INDENT * (indent_level + 1)
      elsif PAREN_OPEN == token && !KEYWORDS_PRIMARY.include?(last_keyword) && !KEYWORDS_SECONDARY.include?(last_keyword)
        skip_next_space = true
        formatted << token
      elsif PAREN_CLOSE == token && !KEYWORDS_PRIMARY.include?(paren_stack.last) && !KEYWORDS_SECONDARY.include?(paren_stack.last)
        formatted << token
      elsif KEYWORDS_PRIMARY.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token
      elsif KEYWORDS_SECONDARY.include?(token)
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token
      else
        formatted << ' ' << token
      end

      # Set states for parenthesis and long `select` handling
      case token
      when SELECT
        comma_count = 0
        (index...tokens.size).each do |next_index|
          comma_count += 1 if COMMA == tokens[next_index]
          break if FROM == tokens[next_index]
        end

        if comma_count >= SELECT_COMMA_LIMIT
          is_long_select = true
          is_new_column = true
          formatted << NEW_LINE << INDENT * (indent_level + 1)
        end
      when FROM then is_long_select = false
      when PAREN_OPEN then paren_stack.push(last_keyword)
      when PAREN_CLOSE then paren_stack.pop
      end

      indent_level += 1 if PAREN_OPEN == token && (KEYWORDS_PRIMARY.include?(last_keyword) || KEYWORDS_SECONDARY.include?(last_keyword))
      last_keyword = token
    end

    formatted.strip
  end
end

# If running specs, stop here
return if ARGV.first&.end_with?('sql_formatter_spec.rb')

# Otherwise, process CLI input
if ARGV.empty?
else
  formatter = SqlFormatter.new(ARGV.join(' '))
  formatter.run

  puts
  puts
  puts formatter.formatted
  puts
end
