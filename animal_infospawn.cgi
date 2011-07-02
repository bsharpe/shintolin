#!/usr/bin/ruby
print "Content-type: text/html\r\n\r\n"
load 'functions.cgi'

def check_animals()
  regions = db_table(:region)
  regions.each {
    |name, region|
    puts name ; puts "/<b>"; puts region[:name]; puts "</b>"
    animals = region[:animals_per_100]
    animals = [] if animals == nil
    puts animals
    animals.each {
      |animal, amt|
      animal_id = db_field(:animal, animal, :id)
      puts "</b><br>";puts animal; puts": spawn factor:"; puts amt
      habitats = habitats(animal)
      habitat_tiles = mysql_select('grid',
        'region_id'=>region[:id],'terrain'=>habitats)
      spawn_no = (habitat_tiles.num_rows / 300.0) * amt #* (rand + 0.5))
      max_allowed = ((habitat_tiles.num_rows / 300.0) * amt) * 10 #(factor of DOOM!)
      puts " avg spawn/day:<b>";puts spawn_no;puts "</b> maximum:<b>"; puts max_allowed; puts "</b>Habitat:<b>"; puts habitat_tiles.num_rows
        }
puts "</b><BR>"
puts "Tiles in region:<b>"; puts mysql_select('grid','region_id'=>region[:id]).num_rows
puts "</b><br><br>"
  }
end

check_animals()
