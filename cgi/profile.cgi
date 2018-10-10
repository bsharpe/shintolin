#!/usr/bin/env ruby
print "Content-type: text/html\r\n\r\n"
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

def input_action(action)
  if action != nil && ($params['magic'] != $user.magic)
    puts "Error. Try again."
    return
  end
  case action
    when 'description'
      mysql_update('accounts', $user.mysql_id,
        {'description' => insert_breaks(CGI::escapeHTML($params['text']))})
    when 'image'
      mysql_update('accounts', $user.mysql_id,
        {'image' => CGI::escapeHTML($params['text'])})
    else ''
  end
end

def change_contact(e_id,type) # modified from function in contacts.cgi
  if $params['magic'] != $user.magic
    return "Error. Try again."
  end
	query = "SELECT COUNT(*) FROM `enemies` WHERE `user_id` = #{$user.mysql_id}"
	result = $mysql.query(query).first
	num_enemies = result['COUNT(*)'].to_i
  if type <= 0
    mysql_delete('enemies',{'user_id'=>$user.mysql_id, 'enemy_id'=>e_id}); return "Contact deleted."
  elsif type > 255
    return "Error. Contact type out of range (maximum 255)."
  else
    enemy = mysql_row('enemies',{'user_id'=>$user.mysql_id, 'enemy_id'=>e_id})
    if enemy == nil
      if num_enemies >= 50 then return "Contact list is full. Delete some contacts if you wish to add more."; end
      mysql_insert('enemies',{'user_id'=>$user.mysql_id, 'enemy_id'=>e_id, 'enemy_type'=>type}); return "Contact added. Now using #{num_enemies+1}/50 contacts."
    else
      if (enemy['enemy_type'].to_i == type) or (enemy['enemy_type'].to_i >=9 && type == 9) then return 'No change.'; end
      mysql_update('enemies',{'user_id'=>$user.mysql_id, 'enemy_id'=>e_id}, {'enemy_type'=>type, 'updated'=>:Now}); return "Contact updated."
    end
  end

end

$params = $cgi.str_params
profile = User.new($params['id'])
user_id = get_validated_id
$user = User.new(user_id) if user_id != false

if !profile.exists? then name = ''
else name = profile.name end

msg = ''
input_action($params['action']) if $user == profile
msg = change_contact($params['id'].to_i, $params['enemy'].to_i) if user_id != false && $params['action'] == "update_contact" && $params['enemy'] != ''
# bug-fix: have to update profile reference as input_action may have
# changed it
profile = User.new($params['id'])

puts <<ENDTEXT
<html>
<head>
<link rel="icon"
      type="image/png"
      href="images/favicon.ico">
<title>Shintolin - #{name}</title>
<link rel='stylesheet' type='text/css' href='shintolin.css' />
</head>
<body>
ENDTEXT

if !profile.exists?
  puts "No user found!</body></html>"
  exit
end

puts <<ENDTEXT
<h1 class='header'>#{name}</h1>

<table>
  <tr>
    <td colspan='2'>
    <div class='beigebox' style='font-style:italic;width:35em'>
    #{profile.description}
    </div>
  </td>
ENDTEXT

if $user == profile
  puts <<ENDTEXT
  <td rowspan='2'>
  <div class='beigebox' style='width:25em'>
  <form method='post' action='profile.cgi?id=#{$user.mysql_id}'>
    Edit description:
    <br>
    <textarea rows='7' cols='36' name='text'>#{$user.description.gsub("<br>", "\r")}</textarea>
    <br><br>
    <input type='hidden' name='action' value='description' />
    <input type='hidden' name='id' value='#{$user.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <hr>
  <form method='post' action='profile.cgi?id=#{$user.mysql_id}'>
    Update image <i>(Enter image URL):</i>
    <br>
    <input type='text' class='text' name='text' maxlength='100' style='width:300px' value='#{profile.image}'/>
    <input type='hidden' name='action' value='image' />
    <input type='hidden' name='id' value='#{$user.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
    <br>
    <i>Images must be hosted on external sites. Offensive content will be removed.</i>
  </form>
  </div>
  </td>
ENDTEXT
elsif user_id != false
  colors = [['#389038', '1', 'green'], ['#902020', '2', 'red'], ['#663399', '3', 'purple'], ['#996600', '4', 'orange'], ['#445044', '5', 'gray'], ['#fafbff', '6', 'white'], ['#330000; color:#f8fbec', '7', 'black'], ['#6f850b', '8', 'yellow-green'], ['#CC6699', '9', 'pink'], ['#c3b080', '', ''], ['#c3b080', '0', 'delete contact']]
  result = mysql_row('enemies', {'user_id'=>$user.mysql_id, 'enemy_id'=>profile.mysql_id})
  if result == nil
    colors.pop # remove "delete contact" option
    result = Hash.new
    result['enemy_id'] = profile.mysql_id; result['enemy_type'] = ''
  end
  relation = $user.relation(profile).to_s
  puts <<ENDTEXT
<font class=#{relation}><b>*</b></font>
<form action ="profile.cgi?id=#{profile.mysql_id}" method ="post">
<input type="hidden" value="#{$user.magic}" name = "magic">
<input type='hidden' name='action' value='update_contact'>
<input type='hidden' name='id' value='#{profile.mysql_id}'>
ENDTEXT
  print '<select style="background-color:#c3b080; color:#203008;" name="enemy">'
  colors.each {|color|
    print '<option style="background-color:' + color[0] + ';" value="' +color[1] +'"'
    if (color[1] ==  result['enemy_type']) or (color[1] == '9' and result['enemy_type'].to_i >= 9) then print ' selected ="yes"' end
    puts '>' + color[2] + '</option>'
}
  puts '</select> <input type="submit" value="Set Contact"> </form> ' + "<font class=#{relation}>" + msg + "</font>"
end

puts <<ENDTEXT
  </tr>
  <tr>
    <td>
    <div class='beigebox'>
    <table>
ENDTEXT
puts "<tr><td><b><i>Donated!</i></b></td></tr>" if profile.donated?
puts "<tr><td><b>"

if $user == profile && profile.temp_sett_id != 0
puts "Settlement (Pending):</td><td>"
else
puts "Settlement:</td><td>#{profile.settlement.link}"
end

if profile.temp_sett_id != 0
  if $user == profile
    pending = mysql_select('settlements',{'id' => $user.temp_sett_id}).first
    puts "<a href=\"settlement.cgi?id=#{$user.temp_sett_id}\" " +
      "class=\"neutral\" " +
      ">#{pending['name']}</a>"
  else puts "(Pending)"
  end
end
puts <<ENDTEXT
	</td>
      </tr>
      <tr>
        <td><b>Level: </td><td>#{profile.level}</td>
      </tr>
      <tr>
        <td><b>Played since: </td><td>#{profile.joined}</td>
      </tr>
ENDTEXT

if profile.hp != 0
  puts "<tr><td><b>Alive since: </td><td>#{profile.lastrevive}</td></tr>"
else
  puts '<tr><td><b>Alive since: </td><td><i>Dazed</i></td></tr>'
end

puts <<ENDTEXT
      <tr>
        <td><b>Frags: </td><td>#{profile.frags}</td>
      </tr>
      <tr>
        <td><b>Kills: </td><td>#{profile.kills}</td>
      </tr>
      <tr>
        <td><b>Deaths: </td><td>#{profile.deaths}</td>
      </tr>
      <tr>
        <td><b>Revives: </td><td>#{profile.revives}</td>
      </tr>
    </table>
    </div>
    </td>

    <td>
    <img style='max-width:300px; max-height:300px' src='#{profile.image}' alt='Portrait of #{profile.name}'/>
    </td>
  </tr>
</table>

<hr>
<a class='buttonlink' href='game.cgi'>Return</a>

</body>
</html>
ENDTEXT
