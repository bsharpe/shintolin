#!/usr/bin/ruby
print "Content-type: text/html\r\n\r\n"
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

puts "<b>Terrains:</b><br>"

terrains = db_table(:terrain).values
terrains.sort! {|x, y| x[:id].to_s <=> y[:id].to_s}

terrains.each do
  |t|
  name = id_to_key(:terrain, t[:id])
  puts "#{name}: #{t[:id]}<br>"
end

puts "<br><br><b>Regions:</b><br>"

terrains = db_table(:region).values
terrains.sort! {|x, y| x[:id].to_s <=> y[:id].to_s}

terrains.each do
  |t|
  name = id_to_key(:region, t[:id])
  game_name = t[:name]
  puts "#{name} / #{game_name}: #{t[:id]}<br>"
end
