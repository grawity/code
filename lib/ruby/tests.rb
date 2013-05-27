#!/usr/bin/env ruby
require 'json'

require './irc.rb'

def parse_test(file)
	File.open(file).each_line do |line|
		line.strip!
		if line.empty? or line.start_with? "//"
			next
		end
		yield JSON.load("[#{line}]")
	end
end

def run_test(file)
	passed, failed = 0, 0
	parse_test(file) do |input, wanted_output|
		actual_output = yield input
		if wanted_output == actual_output
			msg = " OK "
			passed += 1
		else
			msg = "FAIL"
			failed += 1
		end
		puts "#{msg}: #{input.inspect} -> #{JSON.dump(actual_output)}"
	end
	puts "Tests: #{passed} passed, #{failed} failed"
	return failed
end

dir = ".."
f = 0

f += run_test "#{dir}/test-irc-parse.json" do |input|
	begin
		IRC.parse(input).to_a
	rescue RuntimeError
		nil
	end
end

f += run_test "#{dir}/test-irc-unparse.json" do |input|
	begin
		IRC.join(input)
	rescue RuntimeError
		nil
	end
end

puts "Total: #{f} failed"

exit f == 0
