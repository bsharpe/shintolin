#!/usr/bin/env ruby
# frozen_string_literal: true

print "Content-type: text/html\r\n\r\n"

load '/var/www/shn/functions-tick.rb'
puts tick_restore_ap
puts tick_settlement_membership
puts tick_campfires
puts tick_move_animals
