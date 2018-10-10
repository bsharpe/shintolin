def html_action_form(action, inline = false, ap = nil, post = 'game.cgi')
  html = "\n<form action=\"#{post}\" method=\"post\" "
  html += 'style="display:inline" ' if inline
  html += ">\n\t<input type=\"submit\" value=\"" +
          action
  html += ": #{ap}" unless ap.nil?
  html += "\" />\n" +
          html_hidden('action', action.downcase) +
          html_hidden('magic', $user.magic)
  html += yield if block_given?
  html += "\n</form>\n"
  html
end

def html_chat_box(chats = 30)
  query = 'SELECT * FROM `messages` ' \
          "WHERE `type` = 'chat' " \
          'ORDER BY `time` DESC ' \
          "LIMIT 0,#{chats}"
  db_chats = $mysql.query(query)
  chats = ''
  db_chats.each do |chat|
    next if chat['speaker_id'] == '0'

    chats << "<div>#{describe_message(chat)}</div>"
  end
  chats
end

def html_chat_large(chats = 150)
  query = 'SELECT * FROM `messages` ' \
          "WHERE `type` = 'chat' " \
          'ORDER BY `time` DESC ' \
          "LIMIT 0,#{chats}"
  db_chats = $mysql.query(query)
  chats = ''
  db_chats.each do |chat|
    next if chat['speaker_id'] == '0'

    chats << "<div>#{describe_message(chat)}</div>"
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
  if actions.include? :drop
    html += html_action_form('Drop') do
      html_select_num(15) +
        html_select_item(:plural) do |item|
          user_has_item?(user_id, item[:id])
        end
    end
  end
end

def html_forms(user)
  # generate the buttons that should be visible to user
  tile = user.tile
  user_id = user.mysql_id
  players = []
  animals = []
  building = []
  player_rows = mysql_select('users',
                             { 'x' => user.x, 'y' => user.y, 'z' => user.z, 'active' => 1 }, 'id' => user.mysql_id)
  player_rows.each { |row| players << User.new(row['id']) }
  if user.z == 0
    animal_rows = mysql_select('animals', 'x' => user.x, 'y' => user.y)
    animal_rows.each { |row| animals << Animal.new(row['id']) }
  end
  building << tile.building if tile.building.exists?
  has_players = !players.empty?
  has_targets = (has_players || !animals.empty? || !building.empty?)

  actions = user_actions(user)
  html = ''

  if actions.include?(:attack) && has_targets
    html += html_action_form('Attack') do
      html_select_target(animals + players + building) +
        ' with ' +
        html_select_item(:weapon, user_id) do |item|
          (item[:use] == :weapon && user_has_item?(user_id, item[:id])) ||
            item[:id] == 24 # 24 -> fist
        end
    end
  end

  if actions.include? :use
    html += html_action_form('Use') do
      html_select_item do |item|
        !item[:use].nil? && item[:use] != :weapon &&
          user_has_item?(user_id, item[:id])
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

  if actions.include? :craft
    craftables = craft_list(user_id)
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
          user_has_item?(user_id, item[:id])
        end +
        ' to ' +
        html_select_target(players + building)
    end
  end

  if actions.include? :take
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

  if actions.include? :write
    html += html_action_form('Write', false, '3 ap') do
      html_text_box(200) + ' on the building'
    end

  end

  if actions.include? :sow
    html += html_action_form('Sow', false, '15 ap') do
      html_select_item(:plural) do |item|
        item[:plantable] == true
      end
    end
  end
  html += html_action_form('Search', :inline) if actions.include? :search
  if actions.include?(:chop_tree) && (user.z == 0)
    html += html_action_form('Chop Tree', :inline, "#{chop_tree_ap(user_id)}ap")
  end
  if actions.include? :harvest
    html += html_action_form('Harvest', :inline, "#{harvest_ap(user_id)}ap")
  end
  html += html_action_form('Add Fuel', :inline) if actions.include? :add_fuel
  html += html_action_form('Fill', :inline) if actions.include? :fill
  html += html_action_form('Water', :inline) if actions.include? :water
  html += html_action_form('Dig', :inline, '2 ap') if actions.include?(:dig) && (user.z == 0)
  if actions.include? :quarry
    html += html_action_form('Quarry', :inline, '4 ap') end
  if actions.include? :join
    if user.settlement_id == tile.settlement_id
    else
      html += html_action_form('Join Settlement', :inline, '25 ap') end
  end
  html += msg_no_ap(user_id) if actions.include? :no_ap
  html += msg_no_ip if actions.include? :no_ip
  html += html_action_form('Refresh', :inline)
  html
end

def html_hidden(name, value)
  # <input type="hidden" name="x" value="-1">
  html = "\t<input type=\"hidden\" name=\"" +
         name.to_s +
         '" value="' +
         value.to_s +
         "\" />\n"
  html
end

def html_inventory(user_id, y = nil, infix = ' x ', commas = false, inline = false)
  # if y is passed, look for stockpile at location (user_id, y)
  items = db_table(:item).values
  html = "\n"
  weight = 0
  item_descs = items.map do |item|
    item_desc = nil
    amount = if !y.nil?
               stockpile_item_amount(user_id, y, item[:id])
             else
               user_item_amount(user_id, item[:id])
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
    html += '<br>' + db_field(:region, tile.region_id, :name)
  rescue Exception => e
    html += 'The Wilderness'
  end
  html += ' - ' +
          month +
          '</div>'
  html
end

def html_map(centre, size, user = nil, show_occupants = true, &block)
  # generate html to display a map centered on x, y, of size: size x size

  show_buttons =
    if !user.nil? then can_act?(user)
    else false end
  range = (size.to_f / 2).floor
  z =
    if !user.nil? then user.z
    else 0 end

  html = (-range..range).map do |y_offset|
    "\n\t<tr>\n" + (-range..range).map do |x_offset|
                     "\t\t" +
                       html_tile((centre.x + x_offset), (centre.y + y_offset), z,
                                 user, show_buttons, show_occupants, &block)
                   end.to_s + "\n\t</tr>\n"
  end.to_s
  "\n<table>" + html + "\n</table>\n"
end

def html_messages(user_id, x, y, z)
  user = User.new(user_id)
  messages = mysql_get_messages(x, y, z, user)
  html = ''
  messages.each do |row|
    html += "\n\t<div class='#{row['type']}'>" \
            "#{describe_message(row, user_id)}</div>"
  end
  html
end

def html_move_button(dir, ap = 0)
  # displays a move button to travel in direction 'dir'
  # if ap is provided, display that on tile

  if ap.nil? || dir == ''
    html = ''
  else
    x, y, z = dir_to_offset(dir)
    html = "\n\t\t\t<form method = \"POST\" action=\"game.cgi\">" \
           "\n\t\t\t\t<input class=\"movebutton\" type=\"submit\" value=\"" +
           dir
    if z != 0 then ap = 1 end # ap always 1 when entering/exiting
    html += ': ' + ap.to_s + 'ap' if ap != 1 && ap != 0
    html += '"/>' + "\n\t\t\t" +
            html_hidden('action', 'move') + "\t\t\t" +
            html_hidden('x', x) + "\t\t\t" +
            html_hidden('y', y) + "\t\t\t" +
            html_hidden('z', z) +
            html_hidden('magic', $user.magic) +
            '</form>'
  end
  html
end

def html_player_data(user_id)
  user = User.new(user_id)
  player = mysql_user(user_id)
  html = '<center>You are ' +
         html_userlink(user_id, player['name'])
  settlement = user.settlement
  if user.settlement.exists?
    html = if user == settlement.leader
             html + ", #{settlement.title} of "
           else html + ', pledged to '
           end
    html += "<a href=\"settlement.cgi?id=#{settlement.mysql_id}\" " \
           'class="ally" ' \
           ">#{settlement.name}</a>"
  end
  html += '.<br>' \
         " HP: <b>#{player['hp']}/#{player['maxhp']}</b>" \
         " AP: <b>#{player['ap'].to_i.ceil}/#{Max_AP}</b>" \
         " <span style=\"font-size:80%\">(#{ap_recovery(user_id)} AP/hour)</span>" \
         " Hunger: <b>#{player['hunger']}/#{Max_Hunger}</b>" \
         " Level: <b>#{user.level}</b><br>" \
         "<b>XP:</b> #{db_field(:skills_renamed, :name, :wanderer).to_s.capitalize}: <b>#{player['wander_xp']}</b>" \
         " #{db_field(:skills_renamed, :name, :herbalist).to_s.capitalize}: <b>#{player['herbal_xp']}</b>" \
         " #{db_field(:skills_renamed, :name, :crafter).to_s.capitalize}: <b>#{player['craft_xp']}</b>" \
         " #{db_field(:skills_renamed, :name, :warrior).to_s.capitalize}: <b>#{player['warrior_xp']}</b></center>"
end

def html_select(coll, selected = nil)
  html = "\n\t<select name=\"option\">"
  coll.each do |x|
    disp = if block_given?
             yield(x)
           else
             x end
    html += "\n\t\t<option value=\"#{x}\""
    html += ' selected="yes"' if selected == x
    html += ">#{disp}</option>"
  end
  html += "\n\t</select>"
end

def html_select_building(buildings)
  html = "\n\t<select name=\"building\" style=\"width:10em\">\n"
  buildings.each do |building|
    html += "\t\t<option value=\"#{building[:id]}\">"
    html += "#{describe_craft(building)}</option>\n"
  end
  html += "\t</select>\n"
end

def html_select_item(display = :name, user_id = nil)
  # <select name=weapon style='width:10em'><option value=fist>Fist</option>
  # <option value='hand axe'>Hand axe</option></select>
  html = "\n\t<select name=\"item\" style=\"width:10em\">\n"
  items = db_table(:item).values
  items = items.select { |item| yield(item) } if block_given?
  items.each do |item|
    html += "\t\t<option "
    html += 'selected="yes" ' if $params && $params['item'].to_i == item[:id]
    html += 'value="' +
            item[:id].to_s + '">' +
            case display
            when :name then item[:name].capitalize
            when :plural then item[:plural].capitalize
            when :craft then describe_craft(item)
            when :weapon then describe_weapon(item, user_id)
            end
    html += "</option>\n"
  end
  html += "\t</select>\n"
end

def html_select_num(number)
  html = "\n\t<select name=\"number\">\n"
  (1..number).each do |n|
    html += "\t\t<option value=\"" +
            n.to_s + '">' +
            n.to_s +
            "</option>\n"
  end
  html += "\t</select>\n"
end

def html_select_target(targets, default = 'No-one', &block)
  html = "\n\t<select name=\"target\" style=\"width:10em\">\n"
  html += "\t\t<option value=\"0:user\">#{default}</option>\n"

  targets.each do |target|
    html += case target.class.name
            when 'Building'
              html_option_building(target)
            when 'Animal'
              html_option_animal(target)
            else
              html_option_user(target, &block)
            end
  end
  html += "\t</select>\n"
end

def html_option_animal(animal)
  html = "\t\t<option "
  html += 'selected="yes" ' if $target.mysql_id == animal.mysql_id
  html += "value=\"#{animal.mysql_id}:animal\">" \
          "#{animal.name} " \
          "(#{animal.hp}hp)" \
          "</option>\n"
end

def html_option_building(building)
  return '' unless building.exists?

  html = "\t\t<option "
  html += 'selected="yes" ' if $target.is_a? Building
  html += "value=\"#{building.x},#{building.y}:building\">" \
          "#{building.name}</option>\n"
end

def html_option_user(user)
  display =
    if block_given? then yield(user)
    else user.name end

  html = "\t\t<option "
  if !$target.nil? && $target.mysql_id == user.mysql_id
    html += 'selected="yes" ' end
  html += "value=\"#{user.mysql_id}:user\">#{display}</option>\n"
end

def html_skill(skill_name, user_id = 0, indent = 0, xp = 0, form = 'buy')
  # <b style='color:#777777'>Butchering</b> -
  # <i>obtain more meat when killing animals </i><br>

  skill_name = id_to_key(:skill, skill_name) if skill_name.is_a? Integer
  skill = db_row(:skill, skill_name)
  style = if has_skill?(user_id, skill[:id]) then 'bought'
          else 'unbought'
          end

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

  html += "</div>\n"
  subskills = all_where(:skill, :prereq, skill_name)
  unless subskills.empty?
    subskills.each do |sub|
      html += html_skill(sub[:id], user_id, indent + 1, xp, form)
    end
  end
  html
end

def html_skills_list(type, user_id = 0)
  skills = all_where(:skill, :type, type)
  skills.delete_if { |skill| !skill[:prereq].nil? }
  html = ''
  if user_id != 0
    user = User.new(user_id)
    level = user.level(type)
    xp_field = xp_field(type)
    html += "\n<h2>Level #{level} #{db_field(:skills_renamed, :name, type).to_s.capitalize}</h2>" \
            "\nYou have #{user.mysql[xp_field]} #{db_field(:skills_renamed, :name, type)} experience points.<br>\n"
  end
  form = if user.level < Max_Level then 'buy'
         else 'sell'
         end

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
  source_terrain = (user.tile.terrain unless user.nil?)

  html = '<td class="map" style="background-image:url(\'' +
         Image_Folder +
         tile.image + "')\">"

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
            db_field(:building, tile.building_id, :name).capitalize +
            '</span><br>'
  end

  if occupants != true && occupants != :show_occupants
    return html += "\n\t\t</td>\n" end

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
    users = users.num_rows
    if users > 0
      html += '<span class="mapdata">' +
              users.to_s + ' ' +
              if users == 1 then 'person'
              else 'people'
              end
      html += '</span>'
    end
  end
  html += "\n\t\t</td>\n"
end

def html_userlink(id, name = nil, desc = false, show_hp = false)
  name = mysql_user(id)['name'] if name.nil?
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
