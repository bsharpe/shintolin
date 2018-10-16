#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

print $cgi.header

puts "<ul>"
mysql_query('users', {is_admin: 1}).each do |row|

  mysql_update('users', row['id'] , {ap: 999})
  puts "<li>#{row['name']}"
end
puts "</ul>"
puts '<b>Added AP to admins!</b>'

