require_relative 'sql_formatter.constants'

Parenthesis = Struct.new(
  :token, # The token preceding `PAREN_OPEN`
  :is_subquery, # The enclosed value is a subquery
  :is_long_list, # The enclosed value is a long list
  :is_short_list, # The enclosed value is a short list
  :is_conditional # The enclosed value is a conditional
)

module FormatHelpers
  include Constants

  # REMINDER for `#append_*`: For simplicity and readability-
  # - Keep it flat, no nested `if` statements
  # - Keep it short, dedupe as much as possible
  # - Keep it concise, drop redundant conditions
  def append_paren_open!
    # Append with space when preceded by `PAREN_ABLE_KEYWORDS`
    if PAREN_ABLE_KEYWORDS.include?(@f.last_token)
      @f.formatted << ' ' << @f.token
    else
      @f.formatted << @f.token
    end
  end

  def append_after_paren_open!
    # Append with `NEW_LINE` when it's a subquery
    if @f.paren_stack.last.is_subquery
      @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token
    else
      @f.formatted << @f.token
    end
  end

  def append_paren_close!
    # Append with `NEW_LINE` when preceded by a subquery or conditional
    if @f.paren_stack.last.is_subquery || @f.paren_stack.last.is_conditional
      @f.formatted << NEW_LINE << INDENT * (@f.indent_level - 1) << @f.token

    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a long list
    elsif @f.paren_stack.last.is_long_list
      @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token

    else
      @f.formatted << @f.token
    end
  end

  def set_is_long_select!
    case @f.token
    when SELECT then @f.is_long_select = @f.add_new_line = is_long_csv?(SELECT)
    when FROM then @f.is_long_select = false
    end
  end

  def update_paren_stack!
    case @f.token
    when PAREN_OPEN
      paren = Parenthesis.new(@f.last_token)

      if CONDITIONAL_KEYWORDS.include?(@f.last_token)
        paren.is_conditional = @f.add_new_line = true
      elsif QUARY_ABLE_KEYWORDS.include?(@f.last_token)
        paren.is_subquery = SELECT == @f.tokens[@f.index + 1]
        paren.is_long_list = @f.add_new_line = is_long_csv?(PAREN_OPEN)
        paren.is_short_list = (!paren.is_subquery && !paren.is_long_list)
      end

      @f.paren_stack.push(paren)
    when PAREN_CLOSE
      @f.paren_stack.pop
    end
  end

  def is_long_csv?(token)
    char_count = 0
    comma_count = 0
    paren_count = 0

    # Count ahead
    ((@f.index + 1)...@f.tokens.size).each do |next_index|
      next_token = @f.tokens[next_index]

      # Count only 1) `SELECT...FROM` and 2) between matching parenthesis
      case token
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

    # Compare counts to limits
    char_count >= CHAR_LIMIT && comma_count >= COMMA_LIMIT
  end
end
