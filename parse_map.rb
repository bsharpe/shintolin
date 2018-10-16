

require 'rubygems'
require 'chunky_png'
require 'colorize'
puts Dir.pwd
require_relative './lib/data.rb'

old_map = ChunkyPNG::Image.from_file('map.png')
puts "## Map: #{old_map.width} X #{old_map.height}"
width = old_map.width - 1
height = old_map.height - 1
x_offset = 3
y_offset = 4
x_inc = 12
y_inc = 11

map_offset_x = -32
map_offset_y = -32

tile_lookup = $Data[:terrain].each_with_object({}) do |(k, v), result|
  result[k] = v[:id]
end

y = y_offset
while y < height
  x = x_offset
  while x < width
    hex = ChunkyPNG::Color.to_hex(old_map[x, y], false)

    map_x = ((x - x_offset) / x_inc) + map_offset_x
    map_y = ((y - y_offset) / y_inc) + map_offset_y

    x += x_inc

    tile = :wilderness
    case hex.upcase
    when '#495666'
      tile = :wilderness
    when '#C3C3AA'
      tile = :rocky_flat
    when '#AAAC61'
      tile = :flood_plain
    when '#99B254'
      tile = :high_hillside
    when '#A7C772', '#ABC284'
      tile = :mid_hillside
    when '#B9D389', '#8FB146', '#ABC784'
      tile = :low_hillside
    when '#7E8EE2'
      tile = %i[shallow_river deep_river stream].sample
    when '#7066D3'
      tile = :shallow_lake
    when '#7E8EE3'
      tile = :shallow_sea
    when '#7E8EE2'
      tile = :deep_sea
    when '#EBE8CA'
      tile = :sand_beach
    when '#989888'
      tile = :low_cliff_face
    when '#ADAE93', '#ADAF93'
      tile = :cliff_bottom
    when '#63A251'
      tile = :grassland
    when '#94BCD7', '#94BBD7'
      tile = :deep_lake
    when '#274120', '#23521C'
      tile = %i[pine_forest_1 pine_forest_2 pine_forest_3].sample
    when '#80D991'
      tile = :cleared_wood
    when '#415B22'
      tile = :ruins
    else
      puts "  (#{x},#{y}) [#{map_x},#{map_y}] Unknown Color: #{hex.upcase}" unless hex == '#000000'
    end
    tile_id = tile_lookup[tile]
    puts "## UNKNOWN TILE: #{tile}" if tile_id.nil?
    puts "INSERT INTO `grid` (`x`,`y`,`terrain`) VALUES(#{map_x},#{map_y},#{tile_lookup[tile]});" unless tile == :wilderness

  end
  y += y_inc
end
