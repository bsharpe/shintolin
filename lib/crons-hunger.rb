#!/usr/bin/env ruby
# frozen_string_literal: true

print "Content-type: text/html\r\n\r\n"

load '/var/www/shn/functions-tick.rb'
puts tick_hunger
