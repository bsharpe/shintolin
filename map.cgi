#!/usr/bin/ruby
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

user_id = get_validated_id
if user_id != false
  $user = User.new(user_id)
  print "Content-type: text/html\r\n\r\n"
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end
$user = User.new(user_id)

Map = 
if has_skill?($user, :tracking)
  html_map($user.tile, 9, $user, :show_occupants)
else
  html_map($user.tile, 9, $user, :no_occupants)
end

puts <<ENDTEXT
<html>
<head profile="http://www.w3.org/2005/10/profile">
<link rel="icon" 
      type="image/png" 
      href="images/favicon.ico">
<title>Shintolin - Map</title>
<link rel="stylesheet" type="text/css" href="shintolin.css" />
</head>
<body>
<h1>Map</h1>
<hr>
<a class="buttonlink" href="game.cgi">Return</a>
<hr>
<div class="gamebox-light">
#{Map}
</div>
</body>
</html>
ENDTEXT
