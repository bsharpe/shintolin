#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
require 'header.rb'


if current_user
  $header = { cookie: [$cookie], type: 'text/html' }
  puts $cgi.header($header)
else
  puts $cgi.header(Location: 'index.cgi?msg=bad_pw')
  exit
end

def input_action(action)
  return '' if action.nil?
  return 'Error. Try again.' if  $params['magic'] != current_user.magic
  result = case action
    when 'add fuel' then add_fuel(current_user.id, $params['magic'])
    when 'attack' then attack(current_user, $target, $params['item'], $params['magic'])
    when 'build' then build(current_user, $params['building'], $params['magic'])
    when 'chat' then chat(current_user, $params['text'], $params['magic'])
    when 'chop tree' then chop_tree(current_user.id, $params['magic'])
    when 'dig' then dig(current_user, $params['magic'])
    when 'craft' then craft(current_user, $params['item'], $params['magic'])
    when 'drop' then drop(current_user, $params['item'], $params['number'], $params['magic'])
    when 'fill' then fill(current_user, $params['magic'])
    when 'give' then give(current_user, $target, $params['number'], $params['item'], $params['magic'])
    when 'harvest' then harvest(current_user, $params['magic'])
    when 'join settlement' then join(current_user, $params['magic'])
    when 'leave settlement' then leave(current_user, $params['magic'])
    when 'log out' then logout(current_user, $params['magic'])
    when 'move' then move(current_user, $params['x'], $params['y'], $params['z'], $params['magic'])
    when 'quarry' then quarry(current_user, $params['magic'])
    when 'refresh' then ''
    when 'say' then say(current_user, $params['text'], $params['option'], $params['magic'], $target)
    when 'settle' then settle(current_user, $params['text'], $params['magic'])
    when 'search' then search(current_user, $params['magic'])
    when 'sow' then sow(current_user, $params['item'], $params['magic'])
    when 'take' then take(current_user.id, $params['number'], $params['item'], $params['magic'])
    when 'use' then use(current_user, $target, $params['item'], $params['magic'])
    when 'water' then water(current_user, $params['magic'])
    when 'write' then write(current_user, $params['text'], $params['magic'])
    else ''
    end
  mysql_update('users', current_user.id, lastaction: :Now) if result != ''
  result
end

$ip_hits = ip_hit(current_user.id, 0)

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

current_user.update(active: 1)

if (!$params['action'].blank? && current_user.can_act?) || $params['action'] == 'log out' || $params['action'] == 'chat'
  Action_Outcome = input_action($params['action'])
else
  Action_Outcome = ''
end

$ip_hits = ip_hit(current_user.id)

current_user.reload!

tile = current_user.tile
Dazed_Message = msg_dazed(current_user)
Tired_Message = msg_tired(current_user)
Location_Info = describe_location(current_user.id)
Inventory, Encumberance = html_inventory(current_user.id)
Drop = html_drop_item(current_user)
Messages = html_messages(current_user.id, current_user['x'], current_user['y'], current_user['z'])
Location_Bar = html_location_box(current_user)
Map = html_map(current_user.tile, 5, current_user)
Player_Data = html_player_data(current_user)
Action_Forms = html_forms(current_user)
Logout_Button = html_action_form('Log out', true)

load 'game_display.rb'
