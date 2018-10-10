#!/usr/bin/env ruby
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

UserID = get_validated_id
if UserID != false
  print "Content-type: text/html\r\n\r\n"
else
  puts $cgi.header('Location'=>'index.cgi?msg=bad_pw')
  exit
end
$user = User.new(UserID)

def input_action(action)
  case action
    when 'buy' then buy_skill(UserID, $params['skill'], $params['magic'])
    when 'sell' then sell_skill(UserID, $params['skill'], $params['magic'])
    else ""
  end
end

$params = $cgi.str_params
Action_Outcome = input_action($params['action'])
Wanderer_Skills = html_skills_list(:wanderer,UserID)
Herbalist_Skills = html_skills_list(:herbalist,UserID)
Crafter_Skills = html_skills_list(:crafter,UserID)
Warrior_Skills = html_skills_list(:warrior,UserID)

print '<!DOCTYPE html
PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head profile="http://www.w3.org/2005/10/profile">
<link rel="icon" 
      type="image/png" 
      href="images/favicon.ico">
<title>Shintolin - Skills</title>
<link rel="stylesheet" type="text/css" href="shintolin.css" />
</head>
<body>
<h1>Skills</h1>'
print "You have learned #{$user.level} out of a maximum of #{Max_Level} skills.<br>"
print'<hr>
<a class="buttonlink" href="game.cgi">Return</a>
<hr>
'
print "<b>#{Action_Outcome}</b><br>"
print Wanderer_Skills
print Herbalist_Skills
print Crafter_Skills
print Warrior_Skills

print '<br><br>
<a class="buttonlink" href="game.cgi">Return</a>
</body>
</html>'
