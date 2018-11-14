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

occupant_flag = :no_occupants
occupant_flag = :show_occupants if current_user.has_skill?(:tracking)

Map = html_map(current_user.tile, 9, current_user, occupant_flag)

puts <<ENDTEXT
  <html>
  <head profile="http://www.w3.org/2005/10/profile">
  <link rel="icon"
        type="image/png"
        href="images/favicon.ico">
  <title>Shintolin - Map</title>
  <link rel="stylesheet" type="text/css" href="html/shintolin.css" />
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
