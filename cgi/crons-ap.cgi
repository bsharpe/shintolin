#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

puts $cgi.header

require 'functions-tick'


puts tick_restore_ap
puts tick_settlement_membership
puts tick_campfires
puts tick_move_animals
