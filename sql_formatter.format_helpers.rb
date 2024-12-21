#
# This file contains helper methods called by `#format`
#

require_relative 'sql_formatter.constants'

Parenthesis = Struct.new(
  # The token preceding `PAREN_OPEN`
  :token,

  # The type of value following `PAREN_OPEN`
  :is_conditional,
  :is_subquery,
  :is_long_list,
  :is_short_list,
)

module FormatHelpers
  include Constants

  # Reminder for `#append_*`: For simplicity and readability-
  # - Keep it flat, no nested `if` statements
  # - Keep it short, dedupe as much as possible
  # - Keep it concise, drop redundant conditions
  def append_paren_open!(formatted, token, last_token)
    # Append `PAREN_OPEN` with space when preceded by `PAREN_ABLE_KEYWORDS`
    if PAREN_ABLE_KEYWORDS.include?(last_token)
      formatted << ' ' << token
    else
      formatted << token
    end
  end

  def append_after_paren_open!(formatted, token, paren_stack, indent_level)
    # Append subquery with `NEW_LINE` when preceded by `PAREN_OPEN`
    if paren_stack.last.is_subquery
      formatted << NEW_LINE << INDENT * indent_level << token
    else
      formatted << token
    end
  end

  def append_paren_close!(formatted, token, paren_stack, indent_level)
    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by conditional/subquery
    if paren_stack.last.is_conditional || paren_stack.last.is_subquery
      formatted << NEW_LINE << INDENT * (indent_level - 1) << token

    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by long list
    elsif paren_stack.last.is_long_list
      formatted << NEW_LINE << INDENT * indent_level << token

    else
      formatted << token
    end
  end

  def is_long_select?(tokens, index)
    case tokens[index]
    when SELECT then is_long_csv?(tokens, index)
    when FROM then false
    end
  end

  def update_paren_stack!(paren_stack, tokens, index)
    token = tokens[index]
    last_token = tokens[index - 1]
    next_token = tokens[index + 1]

    case token
    when PAREN_OPEN
      paren = Parenthesis.new(last_token)

      if CONDITIONAL_KEYWORDS.include?(last_token)
        paren.is_conditional = true
      elsif QUARY_ABLE_KEYWORDS.include?(last_token)
        paren.is_subquery = SELECT == next_token
        paren.is_long_list = is_long_csv?(tokens, index)
        paren.is_short_list = !paren.is_subquery && !paren.is_long_list
      end

      paren_stack.push(paren)
    when PAREN_CLOSE
      paren_stack.pop
    end
  end

  def is_long_csv?(tokens, index)
    char_count = 0
    comma_count = 0
    paren_count = 0

    start_token = tokens[index]
    ((index + 1)...tokens.size).each do |next_index|
      next_token = tokens[next_index]

      # Count between either `SELECT...FROM` or matching parenthesis
      case start_token
      when SELECT then break if FROM == next_token
      when PAREN_OPEN then break if paren_count < 0
      end

      # Keep track of nested parenthesis and ignore any enclosed `COMMA`
      case next_token
      when PAREN_OPEN then paren_count += 1
      when PAREN_CLOSE then paren_count -= 1
      end

      # Count chars and unnested commas
      case next_token
      when COMMA then comma_count += 1 if paren_count == 0
      else char_count += next_token.size
      end
    end

    # Are we over min thresholds?
    char_count >= CHAR_MIN && comma_count >= COMMA_MIN
  end

  def is_multi_join?(tokens)
    join_counts = [] # Structure: `join_counts[paren_count] = <count>`
    paren_count = 0
    max_join_count = 0

    # Init root level count outside of any parenthesis
    join_counts[0] = 0

    tokens.each.with_index do |token, index|
      # Keep track of nested parenthesis
      case token
      when PAREN_OPEN
        paren_count += 1

        # Init current level count when opening a parenthesis
        join_counts[paren_count] = 0
      when PAREN_CLOSE
        paren_count -= 1

        # Update `max_join_count` when closing a parenthesis
        if max_join_count < join_counts[paren_count]
          max_join_count = join_counts[paren_count]
        end
      end

      # Count `JOIN` on the current parenthesis level
      join_counts[paren_count] += 1 if JOIN == token
    end

    # Update `max_join_count` with root level count
    if max_join_count < join_counts[0]
      max_join_count = join_counts[0]
    end

    # Are we over min threshold?
    max_join_count >= JOIN_MIN
  end
end
