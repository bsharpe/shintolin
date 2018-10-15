#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib' $LOAD_PATH << '../lib/models'
require 'header.rb'

puts $cgi.header


def list(string)
  puts "<li>#{string}</li>"
end

require 'functions-tick'
puts "<html><body><ul>"

list tick_change_leader
list tick_grow_fields
list tick_inactive
list tick_restore_search
list tick_restore_ip
puts tick_spawn_animals
list tick_terrain_transitions
list tick_delete_rotten_food
list tick_rot_food
puts tick_damage_buildings
list tick_delete_empty_data
puts "</ul></body></html>"