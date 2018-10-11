#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

def input_action(action)
  case action
    when 'chat' then chat($user, $params['text'], $params['magic'])
  end
end

UserID = get_validated_id
if UserID != false
  print $cgi.header
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end

$user = User.new(UserID)

input_action $params['action']

puts <<ENDTEXT
<html>
<head profile="http://www.w3.org/2005/10/profile">
<link rel="icon"
      type="image/png"
      href="images/favicon.ico">
<link rel=\"stylesheet\" type=\"text/css\" href=\"/html/shintolin.css\"/>
<title>Chat</title>

<body>
<a class="buttonlink" href="game.cgi">Return</a>
<hr>
#{html_chat_large(150)}
</body>
</html>
ENDTEXT
