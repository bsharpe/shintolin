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
  puts "You are not allowed to print out a map."
  exit
end

if $params['minY'] == "" || $params['minX'] == "" || $params['maxY'] == "" || $params['maxX'] == ""
puts "No map area selected"
exit
end

puts "Y: ("+$params['minY']+" , "+$params['maxY']+")<br>X: ("+$params['minX']+" , "+$params['maxX']+")"
q= (($params['size'].to_i+$params['border'].to_i)*($params['maxX'].to_i-$params['minX'].to_i)+$params['size'].to_i+$params['border'].to_i*2)

puts <<ENDTEXT
<style type="text/css">
<!--
td.border
{
border-width: #{$params['border']}px;
border-color: #{$params['bcolor']};
border-style: solid;
}
-->
</style>
<table cellpadding= 0 cellspacing= 0 style="border-collapse: collapse" align="left" border= #{$params['border']} bordercolor= #{$params['bcolor']} width=
ENDTEXT
puts q
puts "height="
puts (($params['size'].to_i+$params['border'].to_i)*($params['maxY'].to_i-$params['minY'].to_i)+$params['size'].to_i+$params['border'].to_i*2)
puts ">"

for y in ($params['minY'].to_i..$params['maxY'].to_i)
puts "<tr>"
for x in ($params['minX'].to_i..$params['maxX'].to_i)
puts <<ENDTEXT
<td class="border" bgcolor="
ENDTEXT
  tile = mysql_row('grid',{'x'=>x,'y'=>y})
  if tile == nil
			puts '938e4a '
	elsif tile['terrain'] == "1"
puts '63a251 '

else
  case tile['terrain']
	when "1","4","24"
	puts '63a251'
	when "2","22"
	puts '24531f'
	when "3"
	puts '938e4a'


	when "5","52","55","151"
	puts '7592e1'
	when "6","23"
	puts '243f1e'
	when "7","21"
	puts '3d591e'

	when "8","81","82"
	puts 'aaa85b'
	when "9"
	puts '8c8960'
	when "10"
	puts '76d790'

	when "11"
	puts 'c4c2a9'
	when "31"
	puts '99b256'
	when "32"
	puts 'a8c670'

	when "33"
	puts 'c4c2a9'
	when "41"
	puts '8dad3e'
	when "42"
	puts 'acc186'

	when "43"
	puts 'aac582'
	when "44","45"
	puts '2a2a22'
	when "51","111"
	puts '99978a'

	when "53","56"
	puts '6280a4'
	when "54","57"
	puts '8ebdd9'
	when "58"
	puts 'ebe6c9'

	when "59"
	puts '6b6ed5'
	when "91","92"
	puts 'd0bd3d'
	when "99"
	puts 'b16c2b'

	when "110"
	puts 'adac90'
	when "152"
	puts '475767'

	else
	puts 'ffffff'
  end
end

puts <<ENDTEXT
"></td>
ENDTEXT
	   end
	puts "</tr>"
  end
puts "</table>"
