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
terrains = terrains.sort {|x, y| x[:id] <=> y[:id]}

terrains.each do |t|
  name = id_to_key(:terrain, t[:id])
  puts "<li>#{name}: #{t[:id]}<br>"
end
puts "</ul>"
puts "<br><br><b>Regions:</b><br>"
puts "<ul>"
regions = db_table(:region).values
regions = regions.sort {|x, y| x[:id] <=> y[:id]}

regions.each do |t|
  name = id_to_key(:region, t[:id])
  game_name = t[:name]
  puts "<li>#{name} / #{game_name}: #{t[:id]}<br>"
end
puts "</ul>"