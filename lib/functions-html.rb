def html_action_form(action, inline = false, ap = nil, post = 'game.cgi')
  html = "<form action=\"#{post}\" method=\"post\" "
  html += 'style="display:inline" ' if inline
  html += "><input type=\"submit\" value=\"" +
          action
  html += ": #{ap}" unless ap.nil?
  html += "\" />" +
          html_hidden('action', action.downcase) +
          html_hidden('magic', $user.magic)
  html += yield if block_given?
  html += "</form>"
  html
end

def html_chat_box(limit = 30)
  Message.chats(limit).each_with_object([]) do |message, result|
    result << "<div>#{message.to_s}</div>"
  end.join
end

def html_chat_large(limit = 150)
  chats = ''
  Message.chats(limit).each do |message|
    chats << "<div>#{message.to_s}</div>"
  end
  html_action_form('Chat', false, nil, 'chat.cgi') do
    html_text_box(200)
  end +
    '<hr><br><a class="buttonlink" href="chat.cgi">Refresh</a><br><br>' +
    chats
end

def html_drop_item(user)
  # generate the buttons that should be visible to user
  tile = user.tile
  user_id = user.mysql_id
  actions = user_actions(user)
  html = ''
  if actions.include?(:drop)
    html += html_action_form('Drop') do
      html_select_num(15) +
        html_select_item(:plural) do |item|
          user.has_item?(item[:id])
        end
    end
  end
end

def html_forms(user)
  # generate the buttons that should be visible to user
  tile = user.tile
  players = []
  animals = []
  building = []
  user.others_at_location.each { |row| players << User.new(row: row) }
  if user.outside?
    animals = Animal.at_location(user.x, user.y)
  end
  building << tile.building if tile.has_building?

  has_players = !players.empty?
  has_targets = (has_players || !animals.empty? || !building.empty?)

  actions = user_actions(user)
  html = ''

  if actions.include?(:attack) && has_targets
    html += html_action_form('Attack') do
      html_select_target(animals + players + building) +
        ' with ' +
        html_select_item(:weapon, user.id) do |item|
          (item[:use] == :weapon && user.has_item?(item[:id])) || item[:id] == 24 # 24 -> fist
        end
    end
  end

  if actions.include?(:use)
    html += html_action_form('Use') do
      html_select_item do |item|
        !item[:use].nil? && item[:use] != :weapon && user.has_item?(item[:id])
      end +
        ' on ' +
        html_select_target(players, 'Self')
    end
  end

  buildables = build_list(user)
  if actions.include?(:build) && !buildables.empty?
    html += html_action_form('Build') do
      html_select_building(buildables)
    end
  end

  if actions.include?(:craft)
    craftables = craft_list(user.id)
    html += html_action_form('Craft') do
      html_select_item(:craft) do |item|
        craftables.include? item
      end
    end
  end

  if actions.include?(:give) && has_targets
    html += html_action_form('Give') do
      html_select_num(15) +
        html_select_item(:plural) do |item|
          user.has_item?(item[:id])
        end +
        ' to ' +
        html_select_target(players + building)
    end
  end

  if actions.include?(:take)
    html += html_action_form('Take') do
      html_select_num(5) +
        html_select_item(:plural) do |item|
          stockpile_has_item?(user.x, user.y, item[:id])
        end +
        ' from the stockpile.'
    end
  end

  if actions.include?(:speak)
    html += html_action_form('Say') do
      html_text_box(200) + ' to ' +
        html_select_target(players) +
        '<br>Volume: ' +
        html_select(%w[Talk Whisper Shout])
    end

  end

  if actions.include?(:write)
    html += html_action_form('Write', false, '3 ap') do
      html_text_box(200) + ' on the building'
    end

  end

  if actions.include?(:sow)
    html += html_action_form('Sow', false, '15 ap') do
      html_select_item(:plural) do |item|
        item[:plantable] == true
      end
    end
  end
  html += html_action_form('Search', :inline) if actions.include?(:search)
  html += html_action_form('Chop Tree', :inline, "#{chop_tree_ap(user.id)}ap") if actions.include?(:chop_tree) && (user.z == 0)
  html += html_action_form('Harvest', :inline, "#{harvest_ap(user.id)}ap") if actions.include?(:harvest)
  html += html_action_form('Add Fuel', :inline) if actions.include?(:add_fuel)
  html += html_action_form('Fill', :inline) if actions.include?(:fill)
  html += html_action_form('Water', :inline) if actions.include?(:water)
  html += html_action_form('Dig', :inline, '2 ap') if actions.include?(:dig) && (user.z == 0)
  html += html_action_form('Quarry', :inline, '4 ap') if actions.include?(:quarry)
  if actions.include?(:join)
    if user.settlement_id != tile.settlement_id
      html += html_action_form('Join Settlement', :inline, '25 ap')
    end
  end
  html += msg_no_ap(user.id) if actions.include?(:no_ap)
  html += msg_no_ip if actions.include?(:no_ip)
  html += html_action_form('Refresh', :inline)
  html
end

def html_hidden(name, value)
  "<input type=\"hidden\" name=\"#{name}\" value=\"#{value}\" />"
end

def html_inventory(user_id, y = nil, infix = ' x ', commas = false, inline = false)
  # if y is passed, look for stockpile at location (user_id, y)
  user = User.ensure(user_id)
  items = lookup_table(:item).values
  html = ""
  weight = 0
  item_descs = items.map do |item|
    item_desc = nil
    amount = if !y.nil?
               stockpile_item_amount(user_id, y, item[:id])
             else
               user.item_count(item[:id])
             end
    if amount > 0
      weight += (amount * item[:weight])
      item_desc = "<div title=\"#{item[:desc]}\""
      item_desc += ' style="display:inline"' if inline != false
      item_desc += ">#{describe_items(amount, item[:id], :short, infix)}" \
                   '</div>'
    end
    item_desc
  end

  encumberance = case weight
                 when 0 then 'None'
                 when (0..30) then 'Light'
                 when (30..50) then 'Medium'
                 when (50..60) then 'Heavy'
                 when (60..Max_Weight) then 'Very Heavy'
                 else 'You are over encumbered and cannot move'
  end

  html += if commas != false
            describe_list(item_descs)
          else
            item_descs.join
          end

  [html, encumberance]
end

def html_location_box(user)
  tile = Tile.new(user.x, user.y)
  html = '<div class="locationbox">'
  html += tile.settlement.link if tile.settlement
  begin
    html += '<br>' + lookup_table_row(:region, tile.region_id, :name)
  rescue Exception => e
    html += 'The Wilderness'
  end
  html += "[#{user.x},#{user.y}]"  + ' - ' + month + '</div>'
  html
end

def html_map(centre, size, user = nil, show_occupants = true, &block)
  # generate html to display a map centered on x, y, of size: size x size

  show_buttons = !user.nil? ? can_act?(user) : false
  range = (size.to_f / 2).floor
  z = !user.nil? ? user.z : 0

  html = "<table>"
  (-range..range).map do |y_offset|
    html += "<tr>"
    (-range..range).map do |x_offset|
      html += html_tile((centre.x + x_offset), (centre.y + y_offset), z, user, show_buttons, show_occupants, &block)
     end
     html += "</tr>"
  end
  html += "</table>"
  html
end

def html_messages(user, x, y, z)
  user = User.new(user)
  html = []
  Message.for_user(user).each do |message|
    html << "<div class='#{row['type']}'>#{message.to_s(user.id)}</div>"
  end
  html.join
end

def html_move_button(dir, ap = 0)
  # displays a move button to travel in direction 'dir'
  # if ap is provided, display that on tile
  return '' if ap.nil? || dir.blank?

  x, y, z = dir_to_offset(dir)
  ap = 1 if z != 0  # ap always 1 when entering/exiting

  html = %Q[<form method = "POST" action="game.cgi">
            <input class="movebutton" type="submit" value="#{dir}]
  html << ": #{ap}ap" if ap > 1
  html << '"/>'
  html << html_hidden('action', 'move')
  html << html_hidden('x', x)
  html << html_hidden('y', y)
  html << html_hidden('z', z)
  html << html_hidden('magic', $user.magic)
  html << '</form>'
  html
end

def html_player_data(user)
  user = User.ensure(user)
  html = '<center>You are ' + html_userlink(user.id, user.name)
  settlement = user.settlement
  unless user.settlement.nil?
    html = if user == settlement.leader
             html + ", #{settlement.title} of "
           else html + ', pledged to '
           end
    html += "<a href=\"settlement.cgi?id=#{settlement.mysql_id}\" class=\"ally\">#{settlement.name}</a>"
  end
  html += '.<br>' \
         " HP: <b>#{user['hp']}/#{user['maxhp']}</b>" \
         " AP: <b>#{user['ap'].to_i.ceil}/#{Max_AP}</b>" \
         " <span style=\"font-size:80%\">(#{ap_recovery(user.id)} AP/hour)</span>" \
         " Hunger: <b>#{user['hunger']}/#{Max_Hunger}</b>" \
         " Level: <b>#{user.level}</b><br>" \
         "<b>XP:</b> #{lookup_table_row(:skills_renamed, :name, :wanderer).to_s.capitalize}: <b>#{user['wander_xp']}</b>" \
         " #{lookup_table_row(:skills_renamed, :name, :herbalist).to_s.capitalize}: <b>#{user['herbal_xp']}</b>" \
         " #{lookup_table_row(:skills_renamed, :name, :crafter).to_s.capitalize}: <b>#{user['craft_xp']}</b>" \
         " #{lookup_table_row(:skills_renamed, :name, :warrior).to_s.capitalize}: <b>#{user['warrior_xp']}</b></center>"
end

def html_select(coll, selected = nil)
  html = "<select name=\"option\">"
  coll.each do |x|
    disp = block_given? ? yield(x) : x
    html += "<option value=\"#{x}\""
    html += ' selected="yes"' if selected == x
    html += ">#{disp}</option>"
  end
  html += "</select>"
end

def html_select_building(buildings)
  html = "<select name=\"building\" style=\"width:10em\">"
  buildings.each do |building|
    html += "<option value=\"#{building[:id]}\">"
    html += "#{describe_craft(building)}</option>"
  end
  html += "</select>"
end

def html_select_item(display = :name, user_id = nil)
  # <select name=weapon style='width:10em'><option value=fist>Fist</option>
  # <option value='hand axe'>Hand axe</option></select>
  html = "<select name=\"item\" style=\"width:10em\">"
  items = lookup_table(:item).values
  items = items.select { |item| yield(item) } if block_given?
  items.each do |item|
    html += "<option "
    html += 'selected="yes" ' if $params && $params['item'].to_i == item[:id]
    html += 'value="' +
            item[:id].to_s + '">' +
            case display
            when :name then item[:name].capitalize
            when :plural then item[:plural].capitalize
            when :craft then describe_craft(item)
            when :weapon then describe_weapon(item, user_id)
            end
    html += "</option>"
  end
  html += "</select>"
end

def html_select_num(number)
  html = "<select name=\"number\">"
  (1..number).each do |n|
    html += "<option value=\"" +
            n.to_s + '">' +
            n.to_s +
            "</option>"
  end
  html += "</select>"
end

def html_select_target(targets, default = 'No-one', &block)
  html = "<select name=\"target\" style=\"width:10em\">"
  html += "<option value=\"0:user\">#{default}</option>"


  targets.each do |target|
    html += case target.class.name
            when 'Building'
              html_option_building(target)
            when 'Animal'
              html_option_animal(target)
            when 'User'
              html_option_user(target, &block)
            end
  end
  html += "</select>"
end

def html_option_animal(animal)
  html = "<option "
  html += 'selected="yes" ' if $target.mysql_id == animal.mysql_id
  html += "value=\"#{animal.mysql_id}:animal\">" \
          "#{animal.name} " \
          "(#{animal.hp}hp)" \
          "</option>"
end

def html_option_building(building)
  return '' unless building.exists?

  html = "<option "
  html += 'selected="yes" ' if $target.is_a?(Building)
  html += "value=\"#{building.x},#{building.y}:building\">#{building.name}</option>"
end

def html_option_user(user)
  display = block_given? ? yield(user) : user.name

  html = "<option "
  html += 'selected="yes" ' if !$target.nil? && $target.mysql_id == user.mysql_id
  html += "value=\"#{user.mysql_id}:user\">#{display}</option>"
end

def html_skill(skill_name, user_id = 0, indent = 0, xp = 0, form = 'buy')
  # <b style='color:#777777'>Butchering</b> -
  # <i>obtain more meat when killing animals </i><br>

  skill_name = id_to_key(:skill, skill_name) if skill_name.is_a?(Integer)
  skill = lookup_table_row(:skill, skill_name)
  style = has_skill?(user_id, skill[:id]) ? 'bought' : 'unbought'

  html = '<div style="padding:8px">'
  indent.times { html += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp' }
  html += "<b class=\"#{style}\">" +
          skill[:name].capitalize +
          "</b> - <i>#{skill[:desc]}</i>"

  if form == 'buy' && can_buy_skill?(user_id, skill[:id])
    html += '<a onclick=\'javascript:return confirm("Learn skill ' + skill[:name] + '?")\' class=txlinkplain>'
    html += html_action_form('Buy', true, "#{xp}xp", 'skills.cgi') do
      html_hidden('skill', skill[:id])
    end
    html += '</a>'
  end

  if can_sell_skill?(user_id, skill[:id])
    html += '<a onclick=\'javascript:return confirm("Discard skill ' + skill[:name] + '?")\' class=txlinkplain>'
    html += html_action_form('Sell', true, nil, 'skills.cgi') do
      html_hidden('skill', skill[:id])
    end
    html += '</a>'
  end

  html += "</div>"
  subskills = lookup_all_where(:skill, :prereq, skill_name)
  unless subskills.empty?
    subskills.each do |sub|
      html += html_skill(sub[:id], user_id, indent + 1, xp, form)
    end
  end
  html
end

def html_skills_list(type, user_id = 0)
  skills = lookup_all_where(:skill, :type, type)
  skills.delete_if { |skill| !skill[:prereq].nil? }
  html = ''
  if user_id != 0
    user = User.new(user_id)
    level = user.level(type)
    xp_field = xp_field(type)
    html += "<h2>Level #{level} #{lookup_table_row(:skills_renamed, :name, type).to_s.capitalize}</h2>" \
            "You have #{user.mysql[xp_field]} #{lookup_table_row(:skills_renamed, :name, type)} experience points.<br>"
  end
  form = (user.level < Max_Level) ? 'buy' : 'sell'

  skills.each do |skill|
    html += html_skill(skill[:id], user_id, 0, skill_cost(level), form)
  end

  html
end

def html_text_box(max_length)
  '<input type="text" class="text" name="text" ' \
    "maxlength=\"#{max_length}\" style=\"width:#{(max_length * 1.5).to_i}px\" />"
end

def html_tile(x, y, z = 0, user = nil, button = false, occupants = true)
  # get tile at x, y, and format it as html
  # if button is true, include a move button, based on the user's position
  # <td class='map' style=background-image:url('images/p_grass.jpg')></td>

  tile = Tile.new(x, y)
  source_terrain = (user&.tile&.terrain)

  html = '<td class="map" style="background-image:url(' + Image_Folder + tile.image + ')">'

  html += yield(tile) if block_given?

  if button != false
    button = tile_dir(user, tile)
    unless button.nil?
      ap_cost = ap_cost(tile.terrain, source_terrain, user.mysql_id, tile.settlement)
      html += html_move_button(button, ap_cost)
    end
  end

  if !tile.building_id.nil? && tile.building_id != 0
    html += '<span class="mapdata" style="color:#990000">' +
            lookup_table_row(:building, tile.building_id, :name).capitalize +
            '</span><br>'
  end

  if occupants != true && occupants != :show_occupants
    html += "</td>"
    return html
  end

  if z == 0
    animals = mysql_select('animals', 'x' => x, 'y' => y)
    animals = values_freqs_hash(animals, 'type_id')
    animals.each do |type, amt|
      html += '<span class="mapdata" style="color:#0000BB">' +
              describe_animals(amt, type).capitalize +
              '</span><br>'
    end
  end

  # show tile occupants if user is outside, or user is on tile
  if z == 0 || user.tile == tile
    users = mysql_select('users',
                         { 'x' => x, 'y' => y, 'z' => z, 'active' => 1 },
                         'id' => user.mysql_id)
    users = users.count
    if users > 0
      html += '<span class="mapdata">' +
              users.to_s + ' ' +
              if users == 1 then 'person'
              else 'people'
              end
      html += '</span>'
    end
  end
  html += "</td>"
  html
end

def html_userlink(id, name = nil, desc = false, show_hp = false)
  name = User.find(id)['name'] if name.nil?
  user = User.new(id)
  description = ''
  extra = ''
  if desc
    description = mysql_row('accounts', id)['description']
    description = description.slice(0, 140) + '...' if description.length > 140
  end
  if show_hp || user.hp == 0
    if user.hp == 0
      extra = '<span class="small"> [dazed]</span>'
    elsif user.hp < Max_HP
      extra = "<span class=\"small\"> [#{user.hp}/#{user.maxhp}]</span>" end
  end
  relation =
    if !$user.nil? then $user.relation(user).to_s
    else 'neutral' end

  "<a href=\"profile.cgi?id=#{id}\" " \
    "class=\"#{relation}\" " \
    "title=\"#{description}\">" \
    "#{name}</a>#{extra}"
end
