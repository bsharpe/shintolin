#!/usr/bin/env ruby
#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib' $LOAD_PATH << '../lib/models'
require 'header.rb'

print $cgi.header

puts "<b>Terrains:</b><br>"
puts "<ul>"
terrains = lookup_table(:terrain).values
terrains = terrains.sort {|x, y| x[:id] <=> y[:id]}

terrains.each do |t|
  name = id_to_key(:terrain, t[:id])
  puts "<li>#{name}: #{t[:id]}<br>"
end
puts "</ul>"
puts "<br><br><b>Regions:</b><br>"
puts "<ul>"
regions = lookup_table(:region).values
regions = regions.sort {|x, y| x[:id] <=> y[:id]}

regions.each do |t|
  name = id_to_key(:region, t[:id])
  game_name = t[:name]
  puts "<li>#{name} / #{game_name}: #{t[:id]}<br>"
end
puts "</ul>"