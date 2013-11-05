#!/usr/bin/env ruby

ARGF.sort{|a, b| a.length <=> b.length}.each{|x| puts x}
