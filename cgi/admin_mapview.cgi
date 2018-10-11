#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

  query = "select min(x) from grid"
  minX = $mysql.query(query)

  query = "select min(y) from grid"
  minY = $mysql.query(query)

  query = "select max(x) from grid"
  maxX = $mysql.query(query)

  query = "select max(y) from grid"
  maxY = $mysql.query(query)

puts "Maximum map range:<br>"
puts minX.first, maxX.first, minY.first, maxY.first
puts "<br><br><b>Tile Types</b> How much map do you want to make?"

  puts <<ENDTEXT
    <form method='POST' action='terrainprint.cgi'>
    minX: <br>
    <input type='text' class='text' name='minX' maxLength='5'><br>
    maxX: <br>
    <input type='text' class='text' name='maxX' maxLength='5'><br><br>
    minY: <br>
    <input type='text' class='text' name='minY' maxLength='5'><br>
    maxY: <br>
    <input type='text' class='text' name='maxY' maxLength='5'><br><br>
    Cell size (width/height):<br>
    <input type='text' class='text' name='size' maxLength='3' value='4'><br>
    Border:<br>
    <input type='text' class='text' name='border' maxLength='2' value='0'><br>
    Border color:<br>
    <input type='text' class='text' name='bcolor' maxLength='30' value='#004411'><br>
    <hr>
    <input type='submit' value='Make ze Map!' />
    </form>
ENDTEXT

  query = "select min(x) from grid"
  minX = $mysql.query(query)

  query = "select min(y) from grid"
  minY = $mysql.query(query)

  query = "select max(x) from grid"
  maxX = $mysql.query(query)

  query = "select max(y) from grid"
  maxY = $mysql.query(query)

puts "Maximum map range:<br>"
puts minX.first, maxX.first, minY.first, maxY.first
puts "<br><br><b>Regions</b> How much map do you want to make?"

  puts <<ENDTEXT
    <form method='POST' action='regionprint.cgi'>
    minX: <br>
    <input type='text' class='text' name='minX' maxLength='5'><br>
    maxX: <br>
    <input type='text' class='text' name='maxX' maxLength='5'><br><br>
    minY: <br>
    <input type='text' class='text' name='minY' maxLength='5'><br>
    maxY: <br>
    <input type='text' class='text' name='maxY' maxLength='5'><br><br>
    Cell size (width/height):<br>
    <input type='text' class='text' name='size' maxLength='3' value='4'><br>
    Border:<br>
    <input type='text' class='text' name='border' maxLength='2' value='0'><br>
    Border color:<br>
    <input type='text' class='text' name='bcolor' maxLength='30' value='#004411'><br>
    <hr>
    <input type='submit' value='Make ze Map!' />
    </form>
ENDTEXT
