#!/usr/bin/env ruby

require 'cgi'
require 'cgi/session'
require 'functions'
$cgi = CGI.new
print $cgi.header

admins = [] #[1, 5, 40, 2739]
admins.each {|admin| mysql_update('users',admin,{'ap'=>999})}
puts 'Added AP to admins!'

