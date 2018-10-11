#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

UserID = get_validated_id
if UserID != false
  $header = {'cookie' => [$cookie], 'type' => 'text/html'}
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

puts $cgi.header($header)
$user = User.new(UserID)

if !$user.is_admin?
  puts "You cannot edit the map."
  exit
end

def input_action(action)
  case action
    when "north"
      $y = $y - ($size - 1)
    when "south"
      $y = $y + ($size - 1)
    when "west"
      $x = $x - ($size - 1)
    when "east"
      $x = $x + ($size - 1)

    when "location"
      $y = $cgi['y'].to_i
      $x = $cgi['x'].to_i

    when "edit"
      coords_re = /(-?[0-9]+),(-?[0-9]+)/
      $cgi.params.each do |name, value|
	      coords = coords_re.match(name)
	      next if !coords
	      x, y = coords[1], coords[2]
	      update_tile(x, y, $cgi[name])
      end
  end
end

def update_tile(x, y, new_terrain)
  x, y, new_terrain = x.to_i, y.to_i, new_terrain.to_i
  tile = Tile.new(x, y)
  if !tile.exists? && new_terrain != 3 && new_terrain != 0
    mysql_insert('grid',{'x'=>x,'y'=>y, 'terrain'=>new_terrain, 'region_id'=>$params['option']})
  else
      if tile.terrain == new_terrain
      nil
    elsif new_terrain == 0
      mysql_delete('grid',{'x'=>x,'y'=>y})
    else
      mysql_update('grid',{'x'=>x,'y'=>y}, {'terrain'=>new_terrain,'region_id'=>$params['option']})
    end
  end
end

$x = $params['x'].to_i || 0
$y = $params['y'].to_i || 0
$size = $params['size'].to_i
$size = 19 if $size == 0
input_action($params['action'])
$tile = Tile.new($x, $y)

Hidden = html_hidden('x',$x) + html_hidden('y',$y) + html_hidden('size',$size)

def terrain_options_for_select(selected)
  result = []
  $Data[:terrain].each do |id, values|
    if selected == values[:id]
      result << "<option value=\"#{values[:id]}\" selected=true>#{id}</option>"
    else
      result << "<option value=\"#{values[:id]}\">#{id}</option>"
    end
  end
  result.join
end

Map = html_map($tile, $size, nil, :show_occupants) do |tile|
  "<div class=\"small\">#{tile.region_name}</div>" +
  "<select name=\"#{tile.x},#{tile.y}\" style=\"width:100%;\">" +
  terrain_options_for_select(tile.terrain) +
  "</select>" +
  "<br>"
end

Move_Forms =
  html_action_form('West',:inline,nil,'edit-map.cgi') {Hidden} +
  html_action_form('North',:inline,nil,'edit-map.cgi') {Hidden} +
  html_action_form('South',:inline,nil,'edit-map.cgi') {Hidden} +
  html_action_form('East',:inline,nil,'edit-map.cgi') {Hidden} + " | " +
  html_action_form('Goto Coordinates',:inline,nil,'edit-map.cgi') {
  "X:<input type='text' class='text' name='x' maxlength='6' style='width:100px' value='#{$x}'> Y:<input type='text' class='text' name='y' maxlength='6' style='width:100px' value='#{$y}'>
Don't use values beyond -32768 to 32767 (the database uses smallint for x and y)"}

regions = db_table(:region).values
region_ids = regions.map {|r| r[:id]}

Region_Select = html_select(region_ids, $params['option'].to_i) { |id| db_field(:region, id, :name) }

puts <<ENDTEXT
<html>
<head><title>Shintolin - Edit Map</title>
<link rel="stylesheet" type="text/css" href="/html/shintolin.css" />
</head>
<body>
<h1>Edit Map</h1>
<a class='buttonlink' href='game.cgi'>Return</a>
<hr>
#{Move_Forms}
<hr>
<form action="edit-map.cgi" method="post">
<input type="Submit" value="Update" />
<input type="hidden" name="action" value="edit" />
#{Hidden}
 | #{Region_Select} <i>(Edited tiles will join this region)</i> | <b>(Use the number 0 to delete a tile.)</b>
 | See terrain.cgi for list of regions/terrains.
<br>
<hr>
#{Map}
</body>
</html>
ENDTEXT

