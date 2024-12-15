class SqlFormatter
  # Characters with special handling
  COMMA = ','
  ESCAPE = '\\'
  OPERATORS = %w(! = < >)
  PAREN_CLOSE = ')'
  PAREN_OPEN = '('
  QUOTES = %w(' ")
  SEMICOLON = ';'
  SLASH_G = '\\G'

  # Formatting configurations
  INDENT = '  '
  NEW_LINE = "\n"
  SELECT_TOEKN_LIMIT = 10 # Break `select` into multiple lines if over limit

  # When formatting, indent secondary keywords an extra time than primary, e.g
  #  ```
  #  where key1 = 1 # `where` is a primary keyword
  #    and key2 = 2 # `and` is a secondary keyword
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

      # Treat operator as its own tokens
      elsif OPERATORS.include?(char) && !was_operator && open_quote.nil?
        tokens.concat(buffer.split)
        tokens << char
        buffer = ''

      # Pair up consecutive operators; they are always either 1-char or 2-chars
      elsif OPERATORS.include?(char) && was_operator && open_quote.nil?
        tokens.last << char

      # Treat comma and semicolon as their own tokens
      elsif (COMMA == char || SEMICOLON == char) && open_quote.nil?
        tokens.concat(buffer.split)
        tokens << char
        buffer = ''

      # Treat slash-g as its own token
      elsif 'G' == char && was_escape && open_quote.nil?
        tokens.concat(buffer.chop.split)
        tokens << SLASH_G
        buffer = ''

      # Treat open and close parentheses as their own tokens
      elsif (PAREN_OPEN == char || PAREN_CLOSE == char) && open_quote.nil?
        tokens.concat(buffer.split)
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
    tokens.concat(buffer.split)
  end

  def format(tokens)
    formatted = '' # Return value
    indent_level = 0 # Increments right after `(`; decrements right before `)`

    tokens.each do |token|
      indent_level -= 1 if PAREN_CLOSE == token

      if KEYWORDS_PRIMARY.include?(token)
        formatted << NEW_LINE << INDENT * indent_level << token
      elsif KEYWORDS_SECONDARY.include?(token)
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token
      elsif (COMMA == token || SEMICOLON == token)
        formatted << token
      else
        formatted << ' ' << token
      end

      indent_level += 1 if PAREN_OPEN == token
    end

    formatted.strip
  end
end
