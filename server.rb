#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'webrick'
require 'cgi'
require 'yaml'

include WEBrick

port = 9393
dir = Dir.pwd

server = HTTPServer.new(Port: port, DocumentRoot: File.join(dir, 'html'))
server.mount('/', HTTPServlet::FileHandler, File.join(dir, 'cgi'))
server.mount('/images', HTTPServlet::FileHandler, File.join(dir, 'images'))
server.mount('/html', HTTPServlet::FileHandler, File.join(dir, 'html'))
puts "Listening on port: #{port}"

Signal.trap('SIGINT') { server.shutdown }
server.start
