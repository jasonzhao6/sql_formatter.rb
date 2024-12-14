class SqlFormatter
  # Characters with special handling
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")

  # Formatting configurations
  INDENT = '  '
  NEW_LINE = "\n"
  SELECT_TOEKN_LIMIT = 10 # Break `select` into multiple lines if over limit

  # When formatting, indent secondary keywords an extra time than primary, e.g
  #  ```
  #  where key1 = 1 # `where` is a primary keyword
  #    and key2 = 2 # `and` is a secondary keyword
  #  ```
  KEYWORDS_PRIMARY = %w(select from join where order ; \\G \))
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

    # Keep track of open quotes and treat the entire quoted value as one token
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

        tokens.concat(buffer.split)
        buffer = '' << char

      # Handle when switching from a quoted value to a non-quoted value
      elsif QUOTES.include?(char) && !was_escape && open_quote == char
        open_quote = nil

        buffer << char
        tokens << buffer
        buffer = ''

      # Treat comma as its own token
      elsif COMMA == char && open_quote.nil?
        tokens.concat(buffer.split)
        tokens << char
        buffer = ''

      # Pair up consecutive operators; they are always either singles or pairs
      elsif OPERATORS.include?(char) && open_quote.nil? && was_operator
        buffer << char
        tokens.concat(buffer.split)
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
    tokens.concat(buffer.split)
  end

  def format(tokens)
    formatted = '' # Return value
    indent_level = 0 # Increments right after `(`; decrements right before `)`

    tokens.each do |token|
      if KEYWORDS_PRIMARY.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token
      elsif KEYWORDS_SECONDARY.include?(token)
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token
      elsif COMMA == token
        formatted << token
      else
        formatted << ' ' << token
      end
    end

    formatted
  end
end

query = "select t.createdTime, tt.token, t.id\nfrom tranlog t join tranlog_token tt on t.id = tt.tranlog where cardHolder = 570824 and amount = 18.94 order by 1, 2 ;"
query = ARGV.join(' ') unless ARGV.empty?
formatter = SqlFormatter.new(query)
formatter.run

puts query
puts
puts formatter.tokens
puts
puts formatter.formatted
