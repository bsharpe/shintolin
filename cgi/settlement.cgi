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

def input_action(action)
  if action != nil && ($params['magic'] != $user.magic)
    return "Error. Try again."
  end
  case action
    when 'allow_new_users'
      if $params['option'] != '1' and $params['option'] != '0' then return "<br>" end # 1 = yes, 0 = no
      if not [1,11,23,24,28].include?($settlement.region_id) #God's Glade, Scavenger Isles,
                                       #Terra Nullis Si, Terra Nullis Wu, Terra Nullis Jiu
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'allow_new_users' => CGI::escapeHTML($params['option'])})
      else return "This settlement is far too isolated to allow new characters to join." end
    when 'description'
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'description' => insert_breaks(CGI::escapeHTML($params['text']))})
    when 'image'
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'image' => CGI::escapeHTML($params['text'])})
    when 'motto'
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'motto' => CGI::escapeHTML($params['text'])})
    when 'name'
      if $params['text'].length < 2
        return "The settlement name must contain at least 2 characters."
      end
      if $params['text'] != $params['text'].strip
        return "The settlement name must not have spaces at the beginning or end."
      end
      if not $params['text'] =~ /^\s?[a-zA-Z0-9 .\-']*\s?$/
        return "The settlement name contains invalid characters. Use only: spaces 0-9 a-Z . \ - '"
      end
      if mysql_row('settlements',{'name'=>$params['text']}) != nil
        if $params['text'] == $settlement.name
          return "<br>" #"You decide to keep the settlement's name the same."
        else
          return "There is already a settlement with that name."
        end
      end
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'name' => CGI::escapeHTML($params['text'])})
    when 'title'
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'title' => CGI::escapeHTML($params['text'])})
    when 'website'
      mysql_update('settlements', CGI::escapeHTML($params['id']),
        {'website' => CGI::escapeHTML($params['text'])})
    when 'evict'
      if $user.hp <= 0 then return "You are dazed and cannot do that." end
      tile = Tile.new($user.x,$user.y)
      if not tile.building.exists?
        return "You must be at your settlement's totem pole to do that."
      elsif $user.settlement_id != tile.settlement_id or not tile.building.actions.include?(:join)
        return "You must be at your settlement's totem pole to do that." end
      msg = "You ousted "
      number = 0; total = 0
      list = Array.new
      dazed = Array.new
      # make list of dazed settlement members
      $settlement.inhabitants.each do |member|
        dazed[member.mysql_id] = member.name if member.hp <= 0
      end
      $params['dazed'].to_i.times do
        number = number + 1
        option = 'option' + number.to_s
        if $params[option] == nil then next end
        id = $params[option].to_i
        if dazed[id] == nil then next end
        list[total] = "<b>" + dazed[id] + "</b>"
        mysql_update('accounts', id,
          {'settlement_id'=>0})
        query = "$ACTOR ousted you from " +
        "<a href=\"settlement.cgi?id=#{$settlement.mysql_id}\" " +
        "class=\"neutral\" " +
        ">#{$settlement.name}</a>"
        Message.insert(query, speaker: $user, target: id)
        total = total + 1
      end
        msg = msg + describe_list(list)
        if total == 0 then msg = msg + "no one" end
        msg = msg + " from your settlement."
      return msg

    when 'allow_in'
      if $user.hp <= 0 then return "You are dazed and cannot do that." end
      tile = Tile.new($user.x,$user.y)
      if not tile.building.exists?
        return "You must be at your settlement's totem pole to do that."
      elsif $user.settlement_id != tile.settlement_id or not tile.building.actions.include?(:join)
        return "You must be at your settlement's totem pole to do that." end
      msg = "You promoted "
      number = 0; total = 0
      list = Array.new
      pending = Array.new
      # make list of pending settlement members
      $settlement.pendings.each do |member|
        pending[member.mysql_id] = member.name
      end
      $params['pending'].to_i.times do
        number = number + 1
        option = 'option' + number.to_s
        if $params[option] == nil then next end
        id = $params[option].to_i
        if pending[id] == nil then next end
        list[total] = "<b>" + pending[id] + "</b>"
        mysql_update('accounts', id,
          {'settlement_id'=>$settlement.mysql_id,'temp_sett_id'=>0})
        query = "$ACTOR has granted you membership in " +
        "<a href=\"settlement.cgi?id=#{$settlement.mysql_id}\" " +
        "class=\"ally\" " +
        ">#{$settlement.name}</a> early"
        Message.insert(query, speaker: $user, target: id)
        total = total + 1
      end
        msg = msg + describe_list(list)
        if total == 0 then msg = msg + "no one" end
        msg = msg + " to full settlement membership."
      return msg
    else ''
  end
"<br>"
end


$settlement = Settlement.new($params['id'])

if $settlement.exists?
  $leader = $settlement.leader
  $msg = input_action($params['action']) if $leader == $user
  if ($user.exists? && $params['action'] == 'vote' &&
      ($user.settlement == $settlement || $user.temp_sett_id == $settlement.mysql_id) )
    $msg = vote($user, User.new($params['option'])) end
  # bug-fix: have to update settlement reference as input_action may have
  # changed it
  $settlement = Settlement.new($params['id'])
  name = $settlement.name
else
  name = 'None'
end

puts <<ENDTEXT
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

if !$settlement.exists?
  puts 'No settlement found!</body></html>'
  exit
end

puts <<ENDTEXT
<h1 class='header'>#{name}</h1>
<h3 class='header'><i>#{$settlement.motto}</i></h3>
#{$msg}

<table>
  <tr>
  <td colspan='2'>
    <div class='beigebox' style='font-style:italic;width:35em'>
    <b>Website:</b>
    <a href="#{$settlement.website}">#{$settlement.website}</a>
    <br>
    <b>Signup link:</b>
    www.shintolin.co.uk/index.cgi?settlement=#{$settlement.mysql_id}
    <hr>
    #{$settlement.description}
    </div>
  </td>
ENDTEXT

if $user == $leader
  puts <<ENDTEXT
  <td rowspan='3'>
  <div class='beigebox' style='width:28em'>
  <b>Welcome, my #{$settlement.title}.</b>
  <hr>
  <form method='post' action='settlement.cgi'>
    Edit description:
    <br>
    <textarea rows='5' cols='40' name='text'>#{$settlement.description}</textarea>
    <br><br>
    <input type='hidden' name='action' value='description' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <hr>

  <form method='post' action='settlement.cgi'>
    Edit name:
    <br>
    <input type='text' class='text' name='text' maxlength='32' style='width:300px' value="#{$settlement.name}"/>
    <input type='hidden' name='action' value='name' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <form method='post' action='settlement.cgi'>
    Update image <i>(Enter image URL):</i>
    <br>
    <input type='text' class='text' name='text' maxlength='100' style='width:300px' value="#{$settlement.image}"/>
    <input type='hidden' name='action' value='image' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
    <br>
    <i>Images must be hosted on external sites. Offensive content will be removed.</i>
  </form>

  <form method='post' action='settlement.cgi'>
    Edit motto:
    <br>
    <input type='text' class='text' name='text' maxlength='100' style='width:300px' value="#{$settlement.motto}"/>
    <input type='hidden' name='action' value='motto' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <form method='post' action='settlement.cgi'>
    Edit Leader Title:
    <br>
    <input type='text' class='text' name='text' maxlength='20' style='width:300px' value="#{$settlement.title}"/>
    <input type='hidden' name='action' value='title' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

  <form method='post' action='settlement.cgi'>
    Update website <i>(Enter website URL):</i>
    <br>
    <input type='text' class='text' name='text' maxlength='100' style='width:300px' value="#{$settlement.website}"/>
    <input type='hidden' name='action' value='website' />
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>

ENDTEXT
if not [1,11,23,24,28].include?($settlement.region_id)
if $settlement.allow_new_users == 0
  puts "New characters are unable to join #{$settlement.name}. " +
    "Open #{$settlement.name} to new players?"
else
  puts "#{$settlement.name} is open to new characters. " +
    "Keep #{$settlement.name} open?"
end

puts <<ENDTEXT
  <form method='post' action='settlement.cgi'>
    Yes: <input type='radio' name='option' value='1'>
    No: <input type='radio' name='option' value='0'>
    &nbsp;&nbsp;
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type='hidden' name='action' value='allow_new_users' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' value='Submit' />
  </form>
ENDTEXT
else puts "New characters are unable to join #{$settlement.name}. " +
       "This location is far too isolated."
end
end
puts <<ENDTEXT
  </tr>
  <tr>
    <td>
    <div class='beigebox'>
    <table >
      <tr>
        <td><b>Region: </td><td>#{$settlement.region_name}</td>
      </tr>
      <tr>
        <td><b>#{$settlement.title}: </td><td>#{$settlement.leader_link}</td>
      </tr>
      <tr>
        <td><b>Population: </td><td>#{$settlement.population}</td>
      </tr>
      <tr>
        <td><b>Founded: </td><td>#{$settlement.founded}</td>
      </tr>
      <tr>
        <td colspan='2'>
ENDTEXT
if $user != nil && $user.settlement == $settlement
puts "<hr><b><b>Pending Residents: #{describe_list($settlement.pending_links)}"
end
puts <<ENDTEXT
	<hr><b><b>Inhabitants: #{describe_list($settlement.inhabitant_links)}
	</td>
      </tr>
    </table>
    </div>
    </td>
    <td>
    <img style='max-width:300px; max-height:300px' src='#{$settlement.image}' alt="Artist's impression of #{$settlement.name}"/>
    </td>
  </tr>
ENDTEXT
$user = User.new(user_id) if user_id != false
if $user != nil && ($user.settlement == $settlement || $user.temp_sett_id == $settlement.mysql_id)
  candidate_ids = [0] + $settlement.inhabitant_ids
  select_user = html_select(candidate_ids,$user.vote.to_s) do |id|
    if id != 0
      user = User.new id
      "#{user.name} (#{user.supporters} supporters)"
    else
      id
      "- no one -"
    end
  end

  puts <<ENDTEXT
  <tr>
  <td colspan='1'>
  <div class='beigebox'>
ENDTEXT
if $user.settlement != $settlement
  puts "Your vote will <u>not</u> be counted until you achieve residency in #{$settlement.name}."
else puts "As a resident of #{$settlement.name}, you may support someone for leader."
end
puts <<ENDTEXT
    <form action='settlement.cgi' method='post'>
      #{select_user}
    <input type='hidden' name='id' value='#{$settlement.mysql_id}' />
    <input type='hidden' name='action' value='vote' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='Submit' value='Pledge Support' />
    </form>
ENDTEXT
  supported = User.new($user.vote)
  if !supported.exists? || supported.active == 0 || supported.settlement_id != $user.settlement_id || $user.settlement_id == 0 then puts "Current vote: N/A"
  else
    puts "Current vote: #{User.new($user.vote).name}"
  end
  puts <<ENDTEXT
  </div>
  </td>
  <td><div class='beigebox' style='width:18em'>
  Do you wish to relinquish your pledge to #{$settlement.name}? If
  you later decide to rejoin you will have to fulfill the requirements
  to do so once again.<br>
ENDTEXT
  puts '<a onclick=\'javascript:return confirm("Leave ' + $settlement.name + '?")\' class=txlinkplain>'
  puts html_action_form('Leave Settlement', :inline)
puts <<ENDTEXT
</a>
</td></div>
  </tr>
ENDTEXT
end
puts "</table>"

if $user == $leader
puts <<ENDTEXT
<div style="width:65em; background-image: url('images/parchmentbg_dark.jpg'); border:thick solid #c8c8a0">
ENDTEXT
  if $user.hp <= 0 then puts "You can't eject settlement members, nor promote pending members early, while dazed."
  else tile = Tile.new($user.x,$user.y)
    if not tile.building.exists?
      puts "You must be at your settlement's totem pole to eject members, or to allow those attempting to join early membership."
    elsif $user.settlement_id != tile.settlement_id or not tile.building.actions.include?(:join)
      puts "You must be at your settlement's totem pole to eject members, or to allow those attempting to join early membership."
    else
puts <<ENDTEXT
The following players are pending residents and can be granted settlement membership early:
<form action='settlement.cgi' method='post'>
<input type='hidden' name='action' value='allow_in'>
<input type='hidden' name='id' value='#{$settlement.mysql_id}'>
<input type="hidden" value="#{$user.magic}" name = "magic">
ENDTEXT
pending = 0
$settlement.pendings.each do |member|
  pending = pending + 1
  puts "<input type='checkbox' name ='option#{pending}' value ='#{member.mysql_id}'>#{member.name}&nbsp;&nbsp;"
end
if pending == 0 then puts "No one is currently pending." end
puts <<ENDTEXT
<input type='hidden' name='pending' value='#{pending}'>
<br><br>
<input type="submit" value="Expedite membership">
</form>
</div><br>

<div style="width:65em; background-image: url('images/parchmentbg_dark.jpg'); border:thick solid #c8c8a0">
The following players are dazed and their ties to your settlement can be revoked:
<form action='settlement.cgi' method='post'>
<input type='hidden' name='action' value='evict'>
<input type='hidden' name='id' value='#{$settlement.mysql_id}'>
<input type="hidden" value="#{$user.magic}" name = "magic">
ENDTEXT
dazed = 0
$settlement.inhabitants.each do |member|
  if member.hp <= 0
    dazed = dazed + 1
    puts "<input type='checkbox' name ='option#{dazed}' value ='#{member.mysql_id}'>#{member.name}&nbsp;&nbsp;"
  end
end
if dazed == 0 then puts "No one is currently dazed." end
puts <<ENDTEXT
<input type='hidden' name='dazed' value='#{dazed}'>
<br><br>
<input type="submit" value="Abolish membership">
</form>
</div><br>
ENDTEXT
    end
  end
end
puts <<ENDTEXT
</div>
<hr>
<a class='buttonlink' href='game.cgi'>Return</a>
</body>
</html>
ENDTEXT
