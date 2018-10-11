#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

print $cgi.header

admins = [3] #[1, 5, 40, 2739]
admins.each {|admin| mysql_update('users',admin,{'ap'=>999})}
puts 'Added AP to admins!'

