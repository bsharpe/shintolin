#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib' $LOAD_PATH << '../lib/models'
require 'header.rb'

$user = get_user
if $user
  $header = {'cookie' => [$cookie], 'type' => 'text/html'}
  puts $cgi.header($header)
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

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
      $params.each do
        |name, value|
	coords = coords_re.match(name)
	next if !coords
	x, y = coords[1], coords[2]
	update_tile(x, y, value)
      end
  end
end

def update_tile(x, y, new_region)
  x, y, new_region = x.to_i, y.to_i, new_region.to_i
  tile = Tile.new(x, y)
  if !tile.exists? && new_region != 3
    mysql_insert('grid',{'x'=>x,'y'=>y,
      'terrain'=>$params['option'].to_i,'region_id'=>new_region})
  else
      if tile.region_id == new_region
      nil
    else
      mysql_update('grid',{'x'=>x,'y'=>y},
        {'terrain'=>tile.terrain,'region_id'=>new_region})
    end
  end
end

$x = $params['x'].to_i || 0
$y = $params['y'].to_i || 0
$size = $params['size'].to_i
$size = 19 if $size == 0
input_action($params['action'])
$tile = Tile.new($x, $y)

Hidden =
  html_hidden('x',$x) + html_hidden('y',$y) +
  html_hidden('size',$size)

Map = html_map($tile, $size, nil, :show_occupants) do |tile|

  "<div class=\"small\">#{tile.region_name}</div>" +
  "<input type=\"text\" " +
  "class=\"text\" " +
  "name=\"#{tile.x},#{tile.y}\" " +
  "maxlength=\"3\" " +
  "style=\"width:3em\" " +
  "value=\"#{tile.region_id}\" /><br>"
end

Move_Forms =
  html_action_form('West',:inline,nil,'edit-region.cgi') {Hidden} +
  html_action_form('North',:inline,nil,'edit-region.cgi') {Hidden} +
  html_action_form('South',:inline,nil,'edit-region.cgi') {Hidden} +
  html_action_form('East',:inline,nil,'edit-region.cgi') {Hidden} + " | " +
  html_action_form('Goto Coordinates',:inline,nil,'edit-region.cgi') {
  "X:<input type='text' class='text' name='x' maxlength='6' style='width:100px' value='#{$x}'> Y:<input type='text' class='text' name='y' maxlength='6' style='width:100px' value='#{$y}'>
Don't use values beyond -32768 to 32767 (the database uses smallint for x and y)"}

# terrains don't have names, so can't sort by names. Instead:
 Region_Select = "<input type='text' name='option' value='3'>" #3 is the default of wilderness/nothing

puts <<ENDTEXT
<html>
<head><title>Shintolin - Edit Regions</title>
<link rel="stylesheet" type="text/css" href="/html/shintolin.css" />
</head>
<body>
<h1>Edit Regions</h1>
<a class='buttonlink' href='game.cgi'>Return</a>
<hr>
#{Move_Forms}
<hr>
<form action="edit-region.cgi" method="post">
<input type="Submit" value="Update" />
<input type="hidden" name="action" value="edit" />
#{Hidden}
 | #{Region_Select} <i>(Enter a default terrain type (integer). Does not affect exisiting tiles)</i>
 | See terrain.cgi for list of regions/terrains.
<hr>
#{Map}
</body>
</html>
ENDTEXT

