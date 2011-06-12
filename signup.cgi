#!/usr/bin/ruby
require 'cgi'
load 'functions.cgi'
$cgi = CGI.new

$return_page = "index.cgi?settlement=#{$cgi['settlement']}"

if $cgi['username'].length > 24 || $cgi['password_1'].length > 20
  puts $cgi.header('Location'=>$return_page + '&msg=too_long')
  exit
end

if $cgi['username'].length < 2 || $cgi['password_1'].length < 4
  puts $cgi.header('Location'=>$return_page + '&msg=too_short')
  exit
end

if $cgi['username'] != $cgi['username'].strip
puts $cgi.header('Location'=>$return_page + '&msg=invalid_name')
  exit
end

if not $cgi['username'] =~ /^\s?[a-zA-Z0-9 .\-]*\s?$/
  puts $cgi.header('Location'=>$return_page + '&msg=invalid_name')
  exit
end

if $cgi['email'].strip.length < 6
  puts $cgi.header('Location'=>$return_page + '&msg=no_email')
  exit
end

if mysql_row('users',{'name'=>$cgi['username']})
  puts $cgi.header('Location'=>$return_page + '&msg=name_taken')
  exit
end

if $cgi['password_1'] != $cgi['password_2']
  puts $cgi.header('Location'=>$return_page + '&msg=pw_not_match')
  exit
end

password = encrypt($cgi['password_1'])
username = $cgi['username']
settlement = Settlement.new($cgi['settlement'])
unless settlement.exists? && settlement.allow_new_users == 1
  settlement_id = 0
  x, y = rand(40) - 20, rand(40) - 20
else 
  settlement_id = settlement.mysql_id
  x = settlement.x + rand(5) - 2
  y = settlement.y + rand(5) - 2
end

mysql_insert('users',
  {'name'=>username,'password'=>password,'x'=>x,'y'=>y})

id = mysql_row('users',{'name'=>username})['id']
mysql_insert('accounts',
  {'id'=>id,'email'=>$cgi['email'],'joined'=>:Today,
   'lastrevive'=>:Today, 'settlement_id'=> 0, 
   'temp_sett_id'=>settlement_id, 'when_sett_joined' => :Now})

if settlement_id != 0
  mysql_put_message('action',
  "$ACTOR have arrived at a settlement, however you must survive for a day before you are entitled to its privileges.", id, id)
end

mysql_change_inv(id, :noobcake, 9)
puts $cgi.header('Location'=>
  $return_page + "&username=#{username}&msg=account_made")
