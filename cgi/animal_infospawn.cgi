#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

print $cgi.header

def check_animals()
  regions = db_table(:region)
  regions.each do |name, region|
    puts name ; puts "/<b>"; puts region[:name]; puts "</b>"
    animals = region[:animals_per_100] || []
    puts animals
    animals.each do |animal, amt|
      animal_id = db_field(:animal, animal, :id)
      puts "</b><br>";puts animal; puts": spawn factor:"; puts amt
      habitats = habitats(animal)
      habitat_tiles = mysql_select('grid', region_id: region[:id], terrain: habitats)
      spawn_no = (habitat_tiles.num_rows / 300.0) * amt #* (rand + 0.5))
      max_allowed = ((habitat_tiles.num_rows / 300.0) * amt) * 10 #(factor of DOOM!)
      puts " avg spawn/day:<b>";puts spawn_no;puts "</b> maximum:<b>"; puts max_allowed; puts "</b>Habitat:<b>"; puts habitat_tiles.num_rows
    end
    puts "</b><BR>"
    puts "Tiles in region:<b>"; puts mysql_select('grid','region_id'=>region[:id]).num_rows
    puts "</b><br><br>"
  end
end

check_animals()
