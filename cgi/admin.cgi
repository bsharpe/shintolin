#!/usr/bin/env ruby
print "Content-type: text/html\r\n\r\n"
require 'cgi'
require 'cgi/session'
load 'functions.cgi'
$cgi = CGI.new

admins = [] #[1, 5, 40, 2739]
admins.each {|admin| mysql_update('users',admin,{'ap'=>999})}
puts 'Added AP to admins!'

