require_relative 'sql_formatter'
require 'byebug'

# In case of arg mode
input = ARGV.join(' ')

# In case of interactive mode
if ARGV.empty?
  puts 'Enter a sql query (formatting starts after `;` or `\\G`):'
  puts
  puts

  loop do
    input << gets
    break if input.strip.end_with?(';') || input.strip.end_with?('\\G')
  rescue TypeError
    raise '(This file cannot run from TextMate as CLI input is required)'
  end

  puts
  puts
  puts '>>>>>>'
end

# Process input
formatter = SqlFormatter.new(input)
formatter.run

# Print output
puts
puts
puts formatter.formatted
puts
