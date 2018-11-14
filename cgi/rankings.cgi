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

rank = $cgi['metric']
rank = 'frags' if rank == nil

case rank
  when "deaths" then type, metric = "players", "deaths"
  when "frags"
    type, metric = "players", "frags"
    blurb = "Frags measure not just the number of foes killed, " +
      "but the quality of one's opponents. New players begin with " +
      "one frag, and when a character is knocked out, the attacker " +
      "takes half their frags (rounded up)."

  when "kills" then type, metric = "players", "kills"
  when "points" then type, metric = "players", "points"
  when "revives" then type, metric = "players", "revives"
  when "survival"
    type, metric, order = "players", "last_revive", "ASC"
    column = "Last Revived"
    display = Proc.new {|date| Time.str_to_time(date).ago}
    clause = "`hp` != '0' "
  when "oldies"
    type, metric, order = "players", "joined", "ASC"
    display = Proc.new {|date| Time.str_to_time(date).ago}
  when "younguns"
    type, metric = "players", "joined"
    display = Proc.new {|date| Time.str_to_time(date).ago}

  when "bigtowns" then type, metric = "settlements", "population"
  when "newtowns"
    type, metric = "settlements", "founded"
    display = Proc.new {|date| Time.str_to_time(date).ago}
  when "oldtowns"
    type, metric, order = "settlements", "founded", "ASC"
    display = Proc.new {|date| Time.str_to_time(date).ago}
end

if type == "players"
  order = "DESC" if order == nil
  query = "SELECT * FROM `users`, `accounts` " +
    "WHERE `users`.`id` = `accounts`.`id` " +
    (clause ? " AND #{clause} " : '') +
    "AND `active` = '1' " +
    "ORDER BY `#{metric}` #{order} " +
    "LIMIT 0, 100"
  result = db.query(query)
  column = metric.capitalize if column == nil
  $rankings = "<tr> <th>Rank</th> <th>Name</th> <th>#{column}</th></tr>\n"
  result.each_with_index do |row, index|
    user = User.new(row['id'])
    disp = row[metric]
    disp = display.call(row[metric]) if display
    $rankings << "<tr> <td>#{index + 1}</td> <td>#{user.link}</td> <td>#{disp}</td> <tr>\n"
  end
end

if type == "settlements"
  settlements = mysql_select_all('settlements').map{|e| Settlement.new(row: e) }
  settlements = settlements.sort{|x, y| y.send(metric) <=> x.send(metric)}
  settlements = settlements.reverse if order == "ASC"

  column = metric.capitalize if column == nil
  $rankings = "<tr> <th>Rank</th> <th>Name</th> <th>Region</th> <th>#{column}</th> </tr>\n"
  settlements.each_with_index do |settlement, index|
    disp = settlement.send(metric)
    disp = display.call(disp) if display

    $rankings << "<tr> <td>#{index + 1}</td> <td>#{settlement.link}</td> <td><i>#{settlement.region_name}</i></td> <td>#{disp}</td> <tr>\n"
  end
end

puts <<ENDTEXT
<html>
<head>
<link rel="icon" 
      type="image/png" 
      href="images/favicon.ico">
<link rel='stylesheet' type='text/css' href='/html/shintolin.css' />
<title>Shintolin - Rankings</title>
</head>
<body>
It is Year #{game_year}, #{month.to_s} -----
ENDTEXT
query = "SELECT COUNT(*) FROM `users` WHERE `active` = 1"
result = db.query(query).first
puts "Active Users: #{result['COUNT(*)']}"
puts <<ENDTEXT
<hr>
<a class='buttonlink' href='game.cgi'>Return</a>
<hr>
<form method='get' action='rankings.cgi'>
<b>Rank by:</b>
<select width='300px' name='metric'>
<option value='frags'>Frags</option>
<option value='deaths'>Deaths</option>
<option value='kills'>Kills</option>
<option value='revives'>Players Revived</option>
<option value='younguns'>Newest players</option>
<option value='oldies'>Oldest players</option>
<option value='survival'>Longest surviving players</option>
<option value=''>-----</option>
<option value='oldtowns'>Oldest Settlements</option>
<option value='newtowns'>Newest Settlements</option>
<option value='bigtowns'>Most Populous Settlements</option>
</select>
<input type='submit' value='View' />
</form>
<i>#{blurb}</i>
<hr>
<table>
#{$rankings}
</table>

</body>
</html>
ENDTEXT
