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
		if msg == "FAIL"
			puts "\e[33mWANT: #{input.inspect} -> #{JSON.dump(wanted_output)}\e[m"
		end
	end
	puts "Tests: #{passed} passed, #{failed} failed"
	return failed
end

dir = "../tests"
f = 0

f += run_test "#{dir}/irc-split.txt" do |input|
	begin
		IRC.parse(input).to_a
	rescue RuntimeError
		nil
	end
end

f += run_test "#{dir}/irc-join.txt" do |input|
	begin
		IRC.join(input)
	rescue RuntimeError
		nil
	end
end

f += run_test "#{dir}/irc-prefix-split.txt" do |input|
	begin
		IRC::Prefix.parse(input).to_a
	rescue RuntimeError => e
		nil
	end
end

puts "Total: #{f} failed"

exit f == 0
