#!/usr/bin/ruby
#print "Content-type: text/html\r\n\r\n"
require 'cgi'
require 'cgi/session'
load 'functions.cgi'

$cgi = CGI.new
UserID = get_validated_id
if UserID != false
  $header = {'cookie' => [$cookie], 'type' => 'text/html'}
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

puts $cgi.header($header)
$user = User.new(UserID)

if not ["Isaac","Woody","Admin","Buttercup","Miko"].include?($user.name)
puts <<ENDTEXT
You are not allowed to print out a map.
ENDTEXT
exit
end

if $cgi['minY'] == "" || $cgi['minX'] == "" || $cgi['maxY'] == "" || $cgi['maxX'] == ""
puts "No map area selected"
exit
end

puts "Y: ("+$cgi['minY']+" , "+$cgi['maxY']+")<br>X: ("+$cgi['minX']+" , "+$cgi['maxX']+")"
q= (($cgi['size'].to_i+$cgi['border'].to_i)*($cgi['maxX'].to_i-$cgi['minX'].to_i)+$cgi['size'].to_i+$cgi['border'].to_i*2)

puts <<ENDTEXT
<style type="text/css">
<!--
td.border 
{
border-width: #{$cgi['border']}px;
border-color: #{$cgi['bcolor']};
border-style: solid;
}
-->
</style>
<table cellpadding= 0 cellspacing= 0 style="border-collapse: collapse" align="left" border= #{$cgi['border']} bordercolor= #{$cgi['bcolor']} width=
ENDTEXT
puts q
puts "height="
puts (($cgi['size'].to_i+$cgi['border'].to_i)*($cgi['maxY'].to_i-$cgi['minY'].to_i)+$cgi['size'].to_i+$cgi['border'].to_i*2)
puts ">"

for y in ($cgi['minY'].to_i..$cgi['maxY'].to_i)
puts "<tr>"
for x in ($cgi['minX'].to_i..$cgi['maxX'].to_i)
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
