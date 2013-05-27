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
			puts " OK : #{input.inspect} -> #{actual_output.inspect}"
			passed += 1
		else
			puts "FAIL: #{input.inspect} -> #{actual_output.inspect}"
			failed += 1
		end
	end
	puts "Tests: #{passed} passed, #{failed} failed"
end

dir = ".."

run_test "#{dir}/test-irc-parse.json" do |input|
	begin
		msg = IRC.parse(input)
		parv = []
		parv << "@" + msg.tags		if msg.tags
		parv << ":" + msg.prefix	if msg.prefix
		parv += msg.argv		if msg.argv
		parv
	rescue RuntimeError
		nil
	end
end

run_test "#{dir}/test-irc-unparse.json" do |input|
	begin
		IRC.join(input)
	rescue RuntimeError
		nil
	end
end
