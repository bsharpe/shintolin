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

q= (($cgi['size'].to_i+$cgi['border'].to_i)*($cgi['maxX'].to_i-$cgi['minX'].to_i)+$cgi['size'].to_i+$cgi['border'].to_i*2)

puts <<ENDTEXT
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<body bgcolor = "938e4a">
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
<table cellpadding= 0 cellspacing= 0 style="border-collapse: collapse" border=#{$cgi['border']} bordercolor="#{$cgi['bcolor']}" width=
ENDTEXT
puts q
puts "height="
puts (($cgi['size'].to_i+$cgi['border'].to_i)*($cgi['maxY'].to_i-$cgi['minY'].to_i)+$cgi['size'].to_i+$cgi['border'].to_i*2)
puts ">"

#  for x in [minX..maxX]
for y in ($cgi['minY'].to_i..$cgi['maxY'].to_i)
puts "<tr>"
#	 for y in [minY..maxY]
for x in ($cgi['minX'].to_i..$cgi['maxX'].to_i)
puts <<ENDTEXT
<td class="border" bgcolor="
ENDTEXT

  tile = mysql_row('grid',{'x'=>x,'y'=>y})
  if tile == nil
			puts '938e4a'

else 
  case tile['region_id']
	when "1"
	puts '63a251'
	when "2"
	puts '24531f'
	when "3"
	puts 'c39e6a'


	when "4"
	puts '99b256'
	when "5"
	puts '7592e1'
	when "6"
	puts '243f1e'

	when "7"
	puts '3d591e'
	when "8"
	puts 'aa985b'
	when "9"
	puts '8c6980'

	when "10"
	puts '76d790'
	when "11"
	puts 'c4a269'
	when "12"
	puts 'a8d670'

	when "13"
	puts 'b4e2a9'
	when "14"
	puts '6ddd3e'
	when "15"
	puts 'bcc156'

	when "16"
	puts 'dad592'
	when "17"
	puts '99b7ba'
	when "18"
	puts '6280a4'

	when "19"
	puts '8ebdd9'
	when "20"
	puts 'dbb6c9'
	when "21"
	puts '6b6ed5'

	when "22"
	puts 'd0bd3d'
	when "23"
	puts 'b88c90'
	when "24"
	puts '475767'

	when "25"
	puts 'd0ff3d'
	when "26"
	puts 'adff90'
	when "27"
	puts '47ff67'

	when "28"
	puts 'd0bdff'
	when "29"
	puts 'adacff'

    when "0"
    puts '999999'

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

puts <<ENDTEXT
<br><br>
<b>
<font color='63a251'>Region 01 ████████████████████ :name => <font color="black"> '#{db_field(:region, 1, :name)}'<br>
<font color='24531f'>Region 02 ████████████████████ :name => <font color="black"> '#{db_field(:region, 2, :name)}'<br>
<font color='c39e6a'>Region 03 ████████████████████ :name => <font color="black"> '#{db_field(:region, 3, :name)}'<br>

<font color='99b256'>Region 04 ████████████████████ :name => <font color="black"> '#{db_field(:region, 4, :name)}'<br>
<font color='7592e1'>Region 05 ████████████████████ :name => <font color="black"> '#{db_field(:region, 5, :name)}'<br>
<font color='243f1e'>Region 06 ████████████████████ :name => <font color="black"> '#{db_field(:region, 6, :name)}'<br>
	
<font color='3d591e'>Region 07 ████████████████████ :name => <font color="black"> '#{db_field(:region, 7, :name)}'<br>
<font color='aa985b'>Region 08 ████████████████████ :name => <font color="black"> '#{db_field(:region, 8, :name)}'<br>
<font color='8c6980'>Region 09 ████████████████████ :name => <font color="black"> '#{db_field(:region, 9, :name)}'<br>
	
<font color='76d790'>Region 10 ████████████████████ :name => <font color="black"> '#{db_field(:region, 10, :name)}'<br>
<font color='c4a269'>Region 11 ████████████████████ :name => <font color="black"> '#{db_field(:region, 11, :name)}'<br>
<font color='a8d670'>Region 12 ████████████████████ :name => <font color="black"> '#{db_field(:region, 12, :name)}'<br>
	
<font color='b4e2a9'>Region 13 ████████████████████ :name => <font color="black"> '#{db_field(:region, 13, :name)}'<br>
<font color='6ddd3e'>Region 14 ████████████████████ :name => <font color="black"> '#{db_field(:region, 14, :name)}'<br>
<font color='bcc156'>Region 15 ████████████████████ :name => <font color="black"> '#{db_field(:region, 15, :name)}'<br>
	
<font color='dad592'>Region 16 ████████████████████ :name => <font color="black"> '#{db_field(:region, 16, :name)}'<br>
<font color='99b7ba'>Region 17 ████████████████████ :name => <font color="black"> '#{db_field(:region, 17, :name)}'<br>
<font color='6280a4'>Region 18 ████████████████████ :name => <font color="black"> '#{db_field(:region, 18, :name)}'<br>
	
<font color='8ebdd9'>Region 19 ████████████████████ :name => <font color="black"> '#{db_field(:region, 19, :name)}'<br>
<font color='dbb6c9'>Region 20 ████████████████████ :name => <font color="black"> '#{db_field(:region, 20, :name)}'<br>
<font color='6b6ed5'>Region 21 ████████████████████ :name => <font color="black"> '#{db_field(:region, 21, :name)}'<br>

<font color='d0bd3d'>Region 22 ████████████████████ :name => <font color="black"> '#{db_field(:region, 22, :name)}'<br>
<font color='b88c90'>Region 23 ████████████████████ :name => <font color="black"> '#{db_field(:region, 23, :name)}'<br>
<font color='475767'>Region 24 ████████████████████ :name => <font color="black"> '#{db_field(:region, 24, :name)}'<br>
	
<font color='d0ff3d'>Region 25 ████████████████████ :name => <font color="black"> '#{db_field(:region, 25, :name)}'<br>
<font color='adff90'>Region 26 ████████████████████ :name => <font color="black"> '#{db_field(:region, 26, :name)}'<br>
<font color='47ff67'>Region 27 ████████████████████ :name => <font color="black"> '#{db_field(:region, 27, :name)}'<br>
	
<font color='d0bdff'>Region 28 ████████████████████ :name => <font color="black"> '#{db_field(:region, 28, :name)}'<br>
<font color='adacff'>Region 29 ████████████████████ :name => <font color="black"> '#{db_field(:region, 29, :name)}'<br>
	
<font color='999999'>Region 00 ████████████████████ :name => <font color="black"> '#{db_field(:region, 0, :name)}'<br>
<br><br> 
ENDTEXT
