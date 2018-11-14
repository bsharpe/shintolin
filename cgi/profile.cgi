#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'


if current_user
  $header = {cookie: [$cookie], type: 'text/html'}
  puts $cgi.header($header)
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

def input_action(action)
  if !action.nil? && ($params['magic'] != current_user.magic)
    puts 'Error. Try again.'
    return
  end
  case action
  when 'description'
    mysql_update('accounts', current_user.mysql_id,
                 description: insert_breaks(CGI.escapeHTML($params['text'])))
  when 'image'
    mysql_update('accounts', current_user.mysql_id,
                 image: CGI.escapeHTML($params['text']))
  else ''
  end
end

def change_contact(e_id, type) # modified from function in contacts.cgi
  return 'Error. Try again.' if $params['magic'] != current_user.magic

  query = "SELECT COUNT(*) FROM `enemies` WHERE `user_id` = #{current_user.mysql_id}"
  result = db.query(query).first
  num_enemies = result['COUNT(*)'].to_i
  if type <= 0
    mysql_delete('enemies', user_id: current_user.mysql_id, enemy_id: e_id); return 'Contact deleted.'
  elsif type > 255
    return 'Error. Contact type out of range (maximum 255).'
  else
    enemy = mysql_row('enemies', user_id: current_user.mysql_id, enemy_id: e_id)
    if enemy.nil?
      return 'Contact list is full. Delete some contacts if you wish to add more.' if num_enemies >= 50

      mysql_insert('enemies', user_id: current_user.mysql_id, enemy_id: e_id, enemy_type: type); return "Contact added. Now using #{num_enemies + 1}/50 contacts."
    else
      return 'No change.' if (enemy['enemy_type'].to_i == type) || (enemy['enemy_type'].to_i >= 9 && type == 9)

      mysql_update('enemies', { user_id: current_user.mysql_id, enemy_id: e_id }, enemy_type: type, updated: :Now); return 'Contact updated.'
    end
  end
end


profile = User.new($params['id'])

name = profile&.name || ''

msg = ''
input_action($params['action']) if current_user == profile
if current_user && $params['action'] == 'update_contact' && $params['enemy'] != ''
  msg = change_contact($params['id'].to_i, $params['enemy'].to_i)
end
# bug-fix: have to update profile reference as input_action may have
# changed it
profile.reload!

puts <<~ENDTEXT
  <html>
  <head>
  <link rel="icon"
        type="image/png"
        href="images/favicon.ico">
  <title>Shintolin - #{name}</title>
  <link rel='stylesheet' type='text/css' href='/html/shintolin.css' />
  </head>
  <body>
ENDTEXT

if !profile.exists?
  puts 'No user found!</body></html>'
  exit
end

puts <<~ENDTEXT
  <h1 class='header'>#{name}</h1>

  <table>
    <tr>
      <td colspan='2'>
      <div class='beigebox' style='font-style:italic;width:35em'>
      #{profile.description}
      </div>
    </td>
ENDTEXT

if current_user == profile
  puts <<ENDTEXT
  <td rowspan='2'>
  <div class='beigebox' style='width:25em'>
  <form method='post' action='profile.cgi?id=#{current_user.mysql_id}'>
    Edit description:
    <br>
    <textarea rows='7' cols='36' name='text'>#{current_user.description.gsub('<br>', "\r")}</textarea>
    <br><br>
    <input type='hidden' name='action' value='description' />
    <input type='hidden' name='id' value='#{current_user.mysql_id}' />
    <input type="hidden" value="#{current_user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <hr>
  <form method='post' action='profile.cgi?id=#{current_user.mysql_id}'>
    Update image <i>(Enter image URL):</i>
    <br>
    <input type='text' class='text' name='text' maxlength='100' style='width:300px' value='#{profile.image}'/>
    <input type='hidden' name='action' value='image' />
    <input type='hidden' name='id' value='#{current_user.mysql_id}' />
    <input type="hidden" value="#{current_user.magic}" name = "magic">
    <input type='submit' value='Submit' />
    <br>
    <i>Images must be hosted on external sites. Offensive content will be removed.</i>
  </form>
  </div>
  </td>
ENDTEXT
elsif user_id != false
  colors = [['#389038', '1', 'green'], ['#902020', '2', 'red'], ['#663399', '3', 'purple'], ['#996600', '4', 'orange'], ['#445044', '5', 'gray'], ['#fafbff', '6', 'white'], ['#330000; color:#f8fbec', '7', 'black'], ['#6f850b', '8', 'yellow-green'], ['#CC6699', '9', 'pink'], ['#c3b080', '', ''], ['#c3b080', '0', 'delete contact']]
  result = mysql_row('enemies', user_id: current_user.mysql_id, enemy_id: profile.mysql_id)
  if result.nil?
    colors.pop # remove "delete contact" option
    result = {}
    result['enemy_id'] = profile.mysql_id; result['enemy_type'] = ''
  end
  relation = current_user.relation(profile).to_s
  puts <<~ENDTEXT
    <font class=#{relation}><b>*</b></font>
    <form action ="profile.cgi?id=#{profile.mysql_id}" method ="post">
    <input type="hidden" value="#{current_user.magic}" name = "magic">
    <input type='hidden' name='action' value='update_contact'>
    <input type='hidden' name='id' value='#{profile.mysql_id}'>
  ENDTEXT
  print '<select style="background-color:#c3b080; color:#203008;" name="enemy">'
  colors.each do |color|

    print '<option style="background-color:' + color[0] + ';" value="' + color[1] + '"'
    print ' selected ="yes"' if (color[1] == result['enemy_type']) || ((color[1] == '9') && (result['enemy_type'].to_i >= 9))
    puts '>' + color[2] + '</option>'
  end
  puts '</select> <input type="submit" value="Set Contact"> </form> ' + "<font class=#{relation}>" + msg + '</font>'
end

puts <<ENDTEXT
  </tr>
  <tr>
    <td>
    <div class='beigebox'>
    <table>
ENDTEXT
puts '<tr><td><b><i>Donated!</i></b></td></tr>' if profile.donated?
puts '<tr><td><b>'

if current_user == profile && profile.temp_sett_id != 0
  puts 'Settlement (Pending):</td><td>'
else
  puts "Settlement:</td><td>#{profile.settlement.link}"
end

if profile.temp_sett_id != 0
  if current_user == profile
    pending = mysql_select('settlements', id: current_user.temp_sett_id).first
    puts "<a href=\"settlement.cgi?id=#{current_user.temp_sett_id}\" " \
         'class="neutral" ' \
         ">#{pending['name']}</a>"
  else puts '(Pending)'
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
  puts "<tr><td><b>Alive since: </td><td>#{profile.last_revive}</td></tr>"
else
  puts '<tr><td><b>Alive since: </td><td><i>Dazed</i></td></tr>'
end

puts <<~ENDTEXT
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
