#!/usr/bin/env ruby
#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

print $cgi.header

puts "<b>Terrains:</b><br>"
puts "<ul>"
terrains = db_table(:terrain).values
terrains.sort! {|x, y| x[:id].to_s <=> y[:id].to_s}

terrains.each do |t|
  name = id_to_key(:terrain, t[:id])
  puts "<li>#{name}: #{t[:id]}<br>"
end
puts "</ul>"
puts "<br><br><b>Regions:</b><br>"
puts "<ul>"
terrains = db_table(:region).values
terrains.sort! {|x, y| x[:id].to_s <=> y[:id].to_s}

terrains.each do |t|
  name = id_to_key(:region, t[:id])
  game_name = t[:name]
  puts "<li>#{name} / #{game_name}: #{t[:id]}<br>"
end
puts "</ul>"