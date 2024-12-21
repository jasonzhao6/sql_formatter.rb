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

  def append_paren_open!
    # Append `PAREN_OPEN` with space when preceded by `PAREN_ABLE_KEYWORDS`
    if PAREN_ABLE_KEYWORDS.include?(@f.last_token)
      @f.formatted << ' ' << @f.token

    # Append `PAREN_OPEN` without space when preceded by a function call(?)
    else
      @f.formatted << @f.token
    end
  end

  def append_after_paren_open!
    # Append after `PAREN_OPEN` with `NEW_LINE` when it's a subquery
    if @f.paren_stack.last.is_subquery
      @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token

    # Append after `PAREN_OPEN` without space when it's a short list
    elsif @f.paren_stack.last.is_short_list
      @f.formatted << @f.token

    # Append after `PAREN_OPEN` without space when it's a function arg(?)
    else
      @f.formatted << @f.token
    end
  end

  def append_paren_close!
    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a subquery
    if @f.paren_stack.last.is_subquery
      @f.formatted << NEW_LINE << INDENT * (@f.indent_level - 1) << @f.token

    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a long list
    elsif @f.paren_stack.last.is_long_list
      @f.formatted << NEW_LINE << INDENT * @f.indent_level << @f.token

    # Append `PAREN_CLOSE` without space when preceded by a short list
    elsif @f.paren_stack.last.is_short_list
      @f.formatted << @f.token

    # Append `PAREN_CLOSE` with `NEW_LINE` when preceded by a conditional
    elsif @f.paren_stack.last.is_conditional
      @f.formatted << NEW_LINE << INDENT * (@f.indent_level - 1) << @f.token

    # Append `PAREN_CLOSE` without space when preceded by a function call(?)
    else
      @f.formatted << @f.token
    end
  end

  def set_is_long_select!
    case @f.token
    when SELECT
      @f.is_long_select = @f.add_new_line = is_long_csv?
    when FROM
      @f.is_long_select = false
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
        paren.is_long_list = @f.add_new_line = is_long_csv?
        paren.is_short_list = (!paren.is_subquery && !paren.is_long_list)
      end

      @f.paren_stack.push(paren)
    when PAREN_CLOSE
      @f.paren_stack.pop
    end
  end

  def is_long_csv?
    char_count = 0
    comma_count = 0
    paren_count = 0

    # Count ahead
    ((@f.index + 1)...@f.tokens.size).each do |next_index|
      # Count until the next `FROM` to decide `is_long_select`
      break if FROM == @f.tokens[next_index]
      # Count until the matching `PAREN_CLOSE` to decide `is_long_list`
      break if paren_count < 0

      # Keep track of nested parenthesis and ignore any enclosed `COMMA`
      case @f.tokens[next_index]
      when PAREN_OPEN then paren_count += 1
      when PAREN_CLOSE then paren_count -= 1
      end

      case @f.tokens[next_index]
      when COMMA then comma_count += 1 if paren_count == 0 # Count `COMMA`
      else char_count += @f.tokens[next_index].size # Count chars
      end
    end

    # Compare counts to the limits
    char_count >= CHAR_LIMIT && comma_count >= COMMA_LIMIT
  end
end
