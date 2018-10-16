#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

$user = get_user
if $user
  $header = {'cookie' => [$cookie], 'type' => 'text/html'}
  puts $cgi.header($header)
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

def input_action(action)
  if action != nil && ($params['magic'] != $user.magic)
    return "Error. Try again."
  end
  case action
    when 'update_contacts'
      x = Array.new
      $cgi.params.each do
        |key, value|
        if value.to_s == '' then next; end
        if key[0..3] == 'char' then x << key[/\d+/]; x << value.to_s; end
      end
      return change_contacts(x)
    when 'import_contacts'
		x = $cgi['char_list'].scan(/\d+/)
		return change_contacts(x)
    else ''
  end
end

def change_contacts(x) # x = charlist array
	# Find out how many characters the player has in their profile
	# When deleting an existing character, subtract 1
	# When modifying an existing character, no change
	# When adding a character, add 1
	# When 50 is hit, keep going until an attempt to add one is made (deleting/changing = ok)

	# select * from enemies where id = user_id
	query = "SELECT COUNT(*) FROM `enemies` WHERE `user_id` = #{UserID}"
	result = db.query(query).first
	num_enemies = result['COUNT(*)'].to_i

  for i in (1..x.size/2)
    # if type.zero?, then delete
    if x[i*2-1].to_i <= 0
      if mysql_row('enemies',{'user_id'=>UserID, 'enemy_id'=>x[i*2-2].to_i}) == nil
        next
      else
        mysql_delete('enemies',{'user_id'=>UserID, 'enemy_id'=>x[i*2-2].to_i})
        num_enemies = num_enemies - 1
        next
      end
    elsif x[i*2-1].to_i > 255
      return "Error. Contact type for ID# #{x[i*2-2]} out of range (maximum 255). Process stopped."
    else
      enemy = mysql_row('enemies',{'user_id'=>UserID, 'enemy_id'=>x[i*2-2].to_i})
      if enemy == nil
        if num_enemies >= 50 then return "Contact list is full. Delete some contacts if you wish to add more."; end
        num_enemies = num_enemies + 1
        mysql_insert('enemies',{'user_id'=>UserID, 'enemy_id'=>x[i*2-2].to_i, 'enemy_type'=>x[i*2-1].to_i})
      else
        if (enemy['enemy_type'] == x[i*2-1]) or (enemy['enemy_type'].to_i >=9 && x[i*2-1].to_i == 9) then next; end
        mysql_update('enemies',{'user_id'=>UserID, 'enemy_id'=>x[i*2-2].to_i}, {'enemy_type'=>x[i*2-1].to_i, 'updated'=>:Now})
      end
    end
  end
  return "Contact list successfully changed."
end


Action_Outcome = input_action($params['action'])
puts <<ENDTEXT
<html>
<head>
<link rel="icon"
      type="image/png"
      href="images/favicon.ico">
<title>Contact list for #{$user.name}</title>
<link rel='stylesheet' type='text/css' href='html/shintolin.css' />
</head>
<body>
<br><br>
<h1>Contacts</h1>
<a class='buttonlink' href='game.cgi'>Return</a>
<br><br>
ENDTEXT

contacts = 0
# get the contacts/enemies list. List each one.
result = mysql_select('enemies', {'user_id'=>UserID})

enemy_html =''
contacts = 0
colors = [['#389038', '1', 'green'], ['#902020', '2', 'red'], ['#663399', '3', 'purple'], ['#996600', '4', 'orange'], ['#445044', '5', 'gray'], ['#fafbff', '6', 'white'], ['#330000; color:#f8fbec', '7', 'black'], ['#6f850b', '8', 'yellow-green'], ['#CC6699', '9', 'pink'], ['#c3b080', '', ''], ['#c3b080', '0', 'delete contact']]

puts '<table width = "900" background="./images/parchmentbg_dark.jpg" style="border:thick solid #c8c8a0"><td>'
puts '<table width = "450">','<tr><td>ID#</td><td width="100%">Name</td><td>Color/Action</td></tr>'

puts <<ENDTEXT
<form action ="contacts.cgi" method ="post">
<input type="hidden" value="#{$user.lastaction.to_s + $user.name.to_s}" name = "magic">
<input type='hidden' name='action' value='update_contacts'>
<input type='hidden' name='id' value='#{UserID}'>
ENDTEXT

result.each {|row|
  enemy = User.new(row['enemy_id'])
  if not enemy.exists? then puts "<b>ID# #{row['enemy_id']} doesn't exist.</b> Deleted/not added.<br>"; mysql_delete('enemies',{'user_id'=>UserID, 'enemy_id'=>row['enemy_id']}); next end

  enemy_html = enemy_html + row['enemy_id'] + " " + row['enemy_type'] + "; " # contact list export

  contacts += 1
  puts '<tr><td style="text-align:right">' + enemy.mysql_id.to_s + '</td><td width="100%">' + enemy.link + "</td>"
  puts '<td><select style="background-color:#c3b080; color:#203008;" name="char' + enemy.mysql_id.to_s + '">'

  colors.each {|color|
    print '<option style="background-color:' + color[0] + ';" value="' +color[1] +'"'
    if (color[1] ==  row['enemy_type']) or (color[1] == '9' and row['enemy_type'].to_i >= 9) then print ' selected ="yes"' end
    puts '>' + color[2] + '</option>'
  }
  puts '</select></td></tr>'
}

if contacts.positive? 
  puts '<tr><td></td><td><br><input type="submit" value="Make Changes"></td></tr>'
end
puts '</form>'
puts "You have <b>#{contacts}/50</b> contacts used so far.<br><hr></table></td>"

puts <<ENDTEXT
<td style="text-align:left">
Maximum 50 characters.<br> Once the maximum is hit, the process stops.<br>Types:<br>
<b><font color="#407395">0 - delete <font color="#389038">contact/use <font color="#902020">default <font color="#407395">colors. <font color="#389038">1 - green. <font color="#902020"><br>2 - red. <font color="#663399">3 - purple. <font color="#996600">4 - orange. <font color="#445044">5 - gray. <font color="#fafbff">6 - white.<br><font color="#330000">7 - black. <font color="#6f850b">8 - yellow-green. <font color="#CC6699">9-255 - pink. <font color="#000000"><br></b><font color="#000000">
<br>Format: ID# Type#; ID# Type#;<br>

Example:<br>
233 5; 343 7; 346 6; 999 1; 777 0;<br><br>

<form action="contacts.cgi" method="post">
  Character list to import into contacts: <br>
  <textarea class='text' rows='7' cols='40' name='char_list'></textarea> <br>
  <input type="hidden" value="#{$user.lastaction.to_s + $user.name.to_s}" name = "magic">
  <input type='hidden' name='id' value='#{UserID}'>
  <input type='hidden' name='action' value='import_contacts'>
  <input type="submit" value="Import Contacts">
</form>

<br><br>
ENDTEXT

puts "<br><br>Export of your contact list:<br>
<textarea rows='7' cols='40' readonly='readonly'>#{enemy_html}</textarea>"
puts "</td></table>"
puts "</body></html>"
