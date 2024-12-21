require_relative 'sql_formatter'
require 'byebug'

# Accept query via both `ARGV` and `gets`
input = ARGV.join(' ')
if ARGV.empty?
  puts 'Enter a sql query (formatting starts after `;` or `\\G`):'
  puts
  puts

  loop do
    input << gets
    break if input.strip.end_with?(';') || input.strip.end_with?('\\G')
  rescue TypeError
    raise 'A query via `ARGV` or `gets` is required.'
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
