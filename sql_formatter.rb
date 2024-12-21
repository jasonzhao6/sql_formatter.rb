require_relative 'sql_formatter.constants'
require_relative 'sql_formatter.format_helpers'
require 'ostruct'

class SqlFormatter
  include Constants
  include FormatHelpers

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
    open_quote = nil # Valid values: %w(nil ' ")

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
  end

  def split_and_downcase(buffer)
    buffer.split.map do |token|
      (DOWNCASE_ALL_KEYWORDS.include?(token.downcase) ? token.downcase : token)
    end
  end

  def format(tokens)
    # A set of instance vars shared by only this method and its helpers
    # It was created to enable calling helpers without passing long params
    # It was intentionally namespaced to one instance var to keep it contained
    # It was intentionally named one-letter to avoid exceeding line length limit
    @f = OpenStruct.new.tap do |f|
      f.tokens = tokens # Arg
      f.formatted = '' # Return value

      # Break long `SELECT`, list, and compound conditions into multiple lines
      f.is_long_select = false
      f.add_new_line = false

      # Track where we are in the parenthesis stack to apply correct formatting
      f.paren_stack = []

      # Iteration vars to be set
      f.token = nil
      f.index = nil
      f.last_token = nil
      f.indent_level = nil
    end

    # REMINDER: Avoid nested `if` statements; keep it one level for simplicity
    @f.tokens.each.with_index do |token, index|
      # Set iteration vars
      @f.token = token
      @f.index = index
      @f.last_token = @f.tokens[@f.index - 1]
      @f.indent_level = @f.paren_stack.select do |paren|
        paren.is_subquery || paren.is_conditional
      end.size

      # Break long `SELECT` and list into multiple lines
      if (@f.is_long_select || @f.paren_stack.last&.is_long_list) &&
        (@f.add_new_line || COMMA == @f.last_token)

        @f.add_new_line = false
        @f.formatted << NEW_LINE << INDENT * (@f.indent_level + 1) << @f.token

      # Break compound conditions into multiple lines
      elsif @f.paren_stack.last&.is_conditional && @f.add_new_line
        @f.add_new_line = false
        @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token

      # Append `PAREN_OPEN` via helper; there are multiple sub-conditions
      elsif PAREN_OPEN == @f.token
        append_paren_open!

      # Append after `PAREN_OPEN` via helper; there are multiple sub-conditions
      elsif PAREN_OPEN == @f.last_token
        append_after_paren_open!

      # Append `PAREN_CLOSE` via helper; there are multiple sub-conditions
      elsif PAREN_CLOSE == @f.token
        append_paren_close!

      # Append `COMMA` without space
      elsif COMMA == @f.token
        @f.formatted << @f.token

      # Combine `JOIN_KEYWORDS` with space
      elsif JOIN_KEYWORDS.include?(@f.token) &&
        JOIN_KEYWORDS.include?(@f.last_token)

        @f.formatted << ' ' << @f.token

      # Append `NEW_LINE_KEYWORDS` with `NEW_LINE`
      elsif NEW_LINE_KEYWORDS.include?(@f.token)
        @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token

      # Append everything else with space
      else
        @f.formatted << ' ' << @f.token
      end

      # End of iteration tasks
      set_is_long_select!
      update_paren_stack!
    end

    @f.formatted.strip # Strip leading `NEW_LINE`
  end
end
