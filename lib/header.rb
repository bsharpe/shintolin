# frozen_string_literal: true
require 'mysql-connect'
require 'functions-mysql'
require 'functions-html'
require 'functions'

require 'digest/md5'
require 'cgi'
require 'cgi/session'
require 'time'
Dotenv.load("../.env")

$cgi = CGI.new

$mysql = mysql_connect
$params = $cgi

