require_relative 'sql_formatter.constants'
require_relative 'sql_formatter.format_helpers'
require 'byebug'
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

    # Reminder: For simplicity and readability-
    # - Keep it flat, no nested `if` statements
    # - Keep it short, dedupe as much as possible
    # - Keep it concise, drop redundant conditions
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

      # Pair up consecutive operators as one token; they are at most 2-char
      elsif OPERATORS.include?(char) &&
        OPERATORS.include?(last_char) &&
        open_quote.nil?

        tokens.last << char

      # Treat slash-g as its own token
      elsif 'G' == char && ESCAPE == last_char && open_quote.nil?
        tokens.concat(split_and_downcase(buffer.chop))
        tokens << SLASH_G
        buffer = ''

      # Treat `SINGULAR_CHARS` as their own tokens
      elsif SINGULAR_CHARS.include?(char) && open_quote.nil?
        tokens.concat(split_and_downcase(buffer))
        tokens << char
        buffer = ''

      # Accumulate everything else until the next flush event
      else
        buffer << char
      end
    end

    # Final flush
    tokens.concat(split_and_downcase(buffer))
  end

  def split_and_downcase(buffer)
    buffer.split.map do |token|
      (ALL_KEYWORDS.include?(token.downcase) ? token.downcase : token)
    end
  end

  def format(tokens)
    formatted = '' # Return value

    # Break long `SELECT` into multiple lines
    is_long_select = false

    # Inside nested parenthesis, handle compound conditions, subquery, and lists
    paren_stack = []

    # Long `SELECT`, list, and compound conditions need an initial `NEW_LINE`
    add_initial_new_line = false

    # Append with extra `NEW_LINE` in case of multiple `JOIN`
    is_multi_join = is_multi_join?(tokens)

    # Reminder: For simplicity and readability-
    # - Keep it flat, no nested `if` statements
    # - Keep it short, dedupe as much as possible
    # - Keep it concise, drop redundant conditions
    tokens.each.with_index do |token, index|
      last_token = tokens[index - 1]
      indent_level = paren_stack.select do |paren|
        paren.is_conditional || paren.is_subquery
      end.size

      # Break compound conditions into multiple lines
      if paren_stack.last&.is_conditional && add_initial_new_line
        add_initial_new_line = false
        formatted << NEW_LINE << INDENT * indent_level << token

      # Break long `SELECT` and list into multiple lines
      elsif (is_long_select || paren_stack.last&.is_long_list) &&
        (add_initial_new_line || COMMA == last_token)

        add_initial_new_line = false
        formatted << NEW_LINE << INDENT * (indent_level + 1) << token

      # Append `PAREN_OPEN` via helper; there are multiple sub-conditions
      elsif PAREN_OPEN == token
        append_paren_open!(formatted, token, last_token)

      # Append after `PAREN_OPEN` via helper; there are multiple sub-conditions
      elsif PAREN_OPEN == last_token
        append_after_paren_open!(formatted, token, paren_stack, indent_level)

      # Append `PAREN_CLOSE` via helper; there are multiple sub-conditions
      elsif PAREN_CLOSE == token
        append_paren_close!(formatted, token, paren_stack, indent_level)

      # Append `COMMA` without space
      elsif COMMA == token
        formatted << token

      # Append with `NEW_LINE * 2`, unless combining consecutive `JOIN_KEYWORDS`
      elsif is_multi_join &&
        NEW_LINES_KEYWORDS.include?(token) &&
        !JOIN_KEYWORDS.include?(last_token) &&

        formatted << NEW_LINE * 2 << INDENT * indent_level << token

      # Append with `NEW_LINE`, unless combining consecutive `JOIN_KEYWORDS`
      elsif NEW_LINE_KEYWORDS.include?(token) &&
        !JOIN_KEYWORDS.include?(last_token)

        formatted << NEW_LINE << INDENT * indent_level << token

      # Append everything else with space
      else
        formatted << ' ' << token
      end

      case is_long_select?(tokens, index)
      when true then is_long_select = add_initial_new_line = true
      when false then is_long_select = false
      when nil # Maintain current `is_long_select` state
      end

      update_paren_stack!(paren_stack, tokens, index)
      if PAREN_OPEN == token &&
        (paren_stack.last.is_conditional || paren_stack.last.is_long_list)

        add_initial_new_line = true
      else # Maintain current `is_conditional/is_long_list` states
      end
    end

    formatted.strip # Strip leading `NEW_LINE`
  end
end
