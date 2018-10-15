#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'

$user = get_user
if $user
  $header = { 'cookie' => [$cookie], 'type' => 'text/html' }
  puts $cgi.header($header)
else
  puts $cgi.header('Location' => 'index.cgi?msg=bad_pw')
  exit
end

def input_action(action)
  return 'Error. Try again.' if action.nil? || $params['magic'] != $user.magic
  result = case action
    when 'add fuel' then add_fuel($user.id, $params['magic'])
    when 'attack' then attack($user, $target, $params['item'], $params['magic'])
    when 'build' then build($user, $params['building'], $params['magic'])
    when 'chat' then chat($user, $params['text'], $params['magic'])
    when 'chop tree' then chop_tree($user.id, $params['magic'])
    when 'dig' then dig($user, $params['magic'])
    when 'craft' then craft($user, $params['item'], $params['magic'])
    when 'drop' then drop($user, $params['item'], $params['number'], $params['magic'])
    when 'fill' then fill($user, $params['magic'])
    when 'give' then give($user, $target, $params['number'], $params['item'], $params['magic'])
    when 'harvest' then harvest($user, $params['magic'])
    when 'join settlement' then join($user, $params['magic'])
    when 'leave settlement' then leave($user, $params['magic'])
    when 'log out' then logout($user, $params['magic'])
    when 'move' then move($user, $params['x'], $params['y'], $params['z'], $params['magic'])
    when 'quarry' then quarry($user, $params['magic'])
    when 'refresh' then ''
    when 'say' then say($user, $params['text'], $params['option'], $params['magic'], $target)
    when 'settle' then settle($user, $params['text'], $params['magic'])
    when 'search' then search($user, $params['magic'])
    when 'sow' then sow($user, $params['item'], $params['magic'])
    when 'take' then take($user.id, $params['number'], $params['item'], $params['magic'])
    when 'use' then use($user, $target, $params['item'], $params['magic'])
    when 'water' then water($user, $params['magic'])
    when 'write' then write($user, $params['text'], $params['magic'])
    else ''
    end
  mysql_update('users', $user.id, 'lastaction' => :Now) if result != ''
  result
end

$ip_hits = ip_hit($user.id, 0)

if !$params['target'].nil?
  target_id, target_type = $params['target'].split(':')
  $target =
    case target_type
    when 'animal'
      Animal.new(target_id)
    when 'building'
      x, y = target_id.split(',')
      Building.new(x.to_i, y.to_i)
    when 'user'
      User.new(target_id)
    end
else
  $target = nil
end

$user.update(active: 1)

if can_act?($user) || $params['action'] == 'log out' || $params['action'] == 'chat'
  Action_Outcome = input_action($params['action'])
else
  Action_Outcome = ''
end

$ip_hits = ip_hit($user.id)

$user.reload!

tile = $user.tile
Dazed_Message = msg_dazed($user)
Tired_Message = msg_tired($user)
Location_Info = describe_location($user.id)
Inventory, Encumberance = html_inventory($user.id)
Drop = html_drop_item($user)
Messages = html_messages($user.id, $user['x'], $user['y'], $user['z'])
Location_Bar = html_location_box($user)
Map = html_map($user.tile, 5, $user)
Player_Data = html_player_data($user)
Action_Forms = html_forms($user)
Logout_Button = html_action_form('Log out', true)

load 'game_display.rb'
