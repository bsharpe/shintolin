#!/usr/bin/env ruby
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

profile = User.new($cgi['id'])

user_id = get_validated_id
if user_id != false
  $user = User.new(user_id)
  print "Content-type: text/html\r\n\r\n"
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

can_settle, settle_msg = can_settle?($user)

puts <<ENDTEXT
<html>
<head>
<link rel="icon" 
      type="image/png" 
      href="images/favicon.ico">
<title>Shintolin - Settle</title>
<link rel='stylesheet' type='text/css' href='shintolin.css' />
</head>
<body>
<h1 class='header'>Create New Settlement</h1>

<img src='images/p_huts.jpg' width='501px alt='Three stone age huts' style='margin-left:auto;margin-right:auto;' />

<br><br>

<div class='beigebox' style='margin-left:40px;width:400px'>
  <p>#{settle_msg}</p>

ENDTEXT

if can_settle
  puts <<ENDTEXT
  <form method='post' action='game.cgi'>
    <input type='text' style='font-size:110%;margin-left:20px' class='text' maxLength='32' name='text' />
    <input type='hidden' name='action' value='settle' />
    <input type="hidden" value="#{$user.magic}" name = "magic">
    <input type='submit' style='font-size:110%' value='Settle!' />
  </form>
ENDTEXT
end

puts <<ENDTEXT
</div>
<br>
<hr>
<a class='buttonlink' href='game.cgi' />Return</a>

</body>
</html>
ENDTEXT
