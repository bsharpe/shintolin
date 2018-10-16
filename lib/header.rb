

require 'patches'
require 'functions-mysql'
require 'functions-html'
require 'functions'

require 'digest/md5'
require 'cgi'
require 'cgi/session'
require 'time'
Dotenv.load('../.env')

$cgi = CGI.new
$params = $cgi
