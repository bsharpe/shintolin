load 'data.rb'

require 'functions-lookup'
require 'animal'
require 'building'
require 'settlement'
require 'tile'
require 'user'
require 'message'
require 'utils'

def add_fuel(user)
  player = User.ensure(user)
  tile = player.tile

  if !lookup_table_row(:building, tile['building_id'], :actions).include?(:add_fuel)
    return "There's nothing to add fuel to here."
  end

  return 'The fire is very large and is too hot to approach.' if tile['building_hp'].to_i >= 30

  return "You don't have any sticks to add to the fire." if !player.has_item?(:stick)

  mysql_transaction do
    player.change_inv(1, -1)
    tile.update(building_hp: tile.building_hp + 1)
    #  Message.insert( "$ACTOR threw a stick on the fire", speaker: user_id) # waste of DB space
    player.give_xp(:wander, 1)
    player.change_ap(-1)
  end

  'You throw a stick on the fire.'
end

def altitude_mod(dest_terrain, start_terrain, user_id = nil, targ_sett = nil)
  return 0 if start_terrain == dest_terrain

  user = User.ensure(user_id)
  dest_terrain = dest_terrain.to_i
  start_terrain = start_terrain.to_i

  start_altitude = lookup_table_row(:terrain, start_terrain, :altitude).to_i
  dest_altitude  = lookup_table_row(:terrain, dest_terrain,  :altitude).to_i
  altitude = dest_altitude - start_altitude

  cost = case altitude
         when (-1..0)
           0
         when 1
           user&.has_skill?(17) ? 1 : 2 # 17=mountaineering
         end

  if cost
    if dest_terrain == 44 # goto wall
      cost += if [45, 47].include?(start_terrain) # from gate/guardhouse
                4
              else
                # anything besides a gate/guardhouse/wall to a wall
                69
              end
    elsif dest_terrain == 47 # gatehouse
      # || start_terrain.to_i == 45 # wall /#or guardstand/ to gatehouse
      cost += 50 if ![45, 44].include?(start_terrain) && targ_sett && (targ_sett != user.settlement)
    end
  end

  cost
end

def ap_cost(dest_terrain, start_terrain = nil, user_id = nil, targ_sett = nil)
  altitude_mod = if !start_terrain.nil?
                   altitude_mod(dest_terrain, start_terrain, user_id, targ_sett)
                 else
                   0
                 end
  return nil if altitude_mod.nil?

  user = User.ensure(user_id)
  dest_terrain = dest_terrain.to_i

  ap_data = lookup_table_row(:terrain, dest_terrain, :ap)
  if ap_data.is_a?(Numeric)
    ap_data + altitude_mod
  elsif user.nil?
    # ap cost depends on skill, but we have no user_id, so return default cost
    default = ap_data[:default]
    default + altitude_mod if default
  else
    # find lowest ap cost that user has skill for
    ap_data.delete_if { |skill, _ap_cost| skill != :default && !user&.has_skill?(skill) }
    costs = ap_data.values
    costs.empty? ? nil : costs.min + altitude_mod
  end
end

def ap_recovery(user)
  user = User.ensure(user)
  return 1 if user.hp.zero?

  tile = user.tile
  ap = AP_Recovery.to_f
  building_bonus = lookup_table_row(:building, tile.building_id, :ap_recovery)
  ap += building_bonus if !building_bonus.nil? && (user.z != 0 || lookup_table_row(:building, tile.building_id, :floors).zero?)

  tile_bonus = lookup_table_row(:terrain, tile.terrain, :ap_recovery)
  ap += tile_bonus if !tile_bonus.nil?

  ap == ap.to_i ? ap.to_i : ap
end

def attack(attacker, target, item_id)
  if !(item_id.to_i == 24 || attacker.has_item?(item_id)) # 24 -> fist
    return "You don't have #{a_an(lookup_table_row(:item, item_id, :name))}"
  end
  return '' if attacker.mysql.nil? || target.mysql.nil?

  if attacker == target
    return 'You stop yourself before inflicting any self-injury. " \
      "Realizing that this is a cry for help, you turn to your bretheren for their sympathetic counsel.'
  end
  return "You attack #{target.name}, but they're already knocked out." if target.hp.zero?
  return "You can't attack while dazed." if attacker.hp.zero?
  return "#{target.name.capitalize} isn't in the vicinity." if !same_location?(attacker, target)

  if target.is_a?(Building) && target.special == :settlement
    can_attack, msg = can_attack_totem?(target)
    return msg if !can_attack
  end
  if target.is_a?(Building) && target.special == :ruins
    return "You ready yourself to attack, but can't bring yourself to harm the ruins."
  end

  weapon = lookup_table_row(:item, item_id)
  return "You can't attack with that." if weapon[:use] != :weapon
  return 'You need an axe to attack buildings.' if target.is_a?(Building) && weapon[:weapon_class] != :slash

  attacker.change_ap(-1)

  accuracy = item_stat(item_id, :accuracy, attacker)
  dmg = target&.is_a?(Building) ? rand_to_i(1.333) : item_stat(item_id, :effect, attacker)

  if rand(100) > accuracy || accuracy.zero?
    msg = lookup_table_row(:weapon_class, weapon[:weapon_class], :miss_msg) +
          weapon[:name] +
          ', but missed!'
    msg << ' ' + attack_response(target, attacker)

    return insert_names(msg, attacker.id, target.name, attacker.id, :no_link)
  end

  kill = deal_damage(dmg, target)

  msg = lookup_table_row(:weapon_class, weapon[:weapon_class], :hit_msg) + weapon[:name]

  if kill
    attacker.give_xp(:warrior, (20 + dmg))
    case target.class.name
    when 'User'
      mysql_change_stat(attacker, 'kills', +1)
      mysql_change_stat(target, 'deaths', +1)
      msg << ', knocking $TARGET out.'
      msg << ' ' + transfer_frags(attacker, target)
      Message.insert("$ACTOR dazed $TARGET with #{a_an(lookup_table_row(:item, item_id, :name))}.",
                     type: 'visible_all',
                     speaker: attacker, target: target)
    when 'Animal'
      target.loot.each do |item, amt|
        attacker.change_inv(item, +amt)
      end
      msg << ', killing it! From the carcass you collect ' \
             "#{describe_items_list(target.loot, 'long')}."
      if attacker.has_skill?(7) # 7 ->butchering temporary fix for butchering
        target.loot_bonus.each do |item, amt|
          attacker.change_inv(item, +amt)
          msg += "<br><br>You also manage to collect #{describe_items_list(target.loot_bonus, 'long')}" \
            " extra with your butchering prowess."
        end
        Message.insert("$ACTOR killed #{a_an(target.name_only)} with #{a_an(lookup_table_row(:item, item_id, :name))}",
                       type: 'visible_all',
                       speaker: attacker, target: target)
      end
    when 'Building'
      msg << ', destroying it!'
    end
  else
    xp = ((dmg + 1) / 2).ceil
    attacker.give_xp(:warrior, xp)
    msg += " for #{dmg} hp damage. #{attack_response(target, attacker)}"
  end

  case target.class.name
  when 'User'
    Message.insert(msg, speaker: attacker, target: target)
  when 'Animal'
    #      Message.insert('action', msg, attacker.id) # waste of DB space
  when 'Building'
    Message.insert("$ACTOR attacked #{target.a}", type: 'persistent', speaker: attacker)
  end

  msg += " #{break_attempt(attacker, item_id)}"

  insert_names(msg, attacker.id, target.name, attacker.id, :no_link)
end

def attack_response(target, attacker)
  msg = ''
  case target.class.name
  when 'Animal'
    response = random_select(target.when_attacked, 100)
    case response
    when :attack
      dmg = target.attack_dmg
      kill = deal_damage(dmg, attacker)
      if kill
        mysql_change_stat(attacker, 'deaths', +1)
        msg = "#{target.name.capitalize} #{target.hit_msg}, knocking $ACTOR out!"
      else
        msg = "#{target.name.capitalize} #{target.hit_msg}, for #{dmg} hp damage."
      end
    when :flee
      msg = "#{target.name.capitalize} flees the area." if move_animal(target)
    end
  when 'User'
    msg = '$TARGET flinched.'
  end
  msg
end

def break_attempt(user, items)
  msg = ''
  return msg if items.nil?

  user = User.ensure(user)

  if items.is_a?(Array)
    items.each { |item| msg << " #{break_attempt(user, item)}" }
    return msg
  end

  item = lookup_table_row(:item, items)
  break_odds = item[:break_odds]
  break_odds = 0 if break_odds.nil?

  if (rand * 100) < break_odds
    user.change_inv(item[:id], -1)
    msg << "Your cherished #{item[:name]} breaks! You throw away the useless pieces in disgust."
  end

  msg
end

def build(user, building_id)
  building_id = building_id.to_i
  tile = user.tile
  return repair(user) if tile.building_id == building_id

  building = lookup_table_row(:building, building_id)

  can_build, msg = can_build?(user, building)
  return msg if !can_build

  update_hash = {}
  case building[:special]
  when :settlement
    can_settle, can_settle_msg = can_settle?(tile)
    if can_settle
      $header['Location'] = 'settle.cgi'
      return '...should be automatically redirected to settle.cgi...'
    end
    return can_settle_msg
  when :terrain
    terrain_id = lookup_table_row(:terrain, building[:terrain_type])
    update_hash['terrain'] = terrain_id
    update_hash['hp'] = building[:build_hp]
  when :walls
    terrain_id = lookup_table_row(:terrain, building[:terrain_type])
    update_hash['terrain'] = terrain_id
    update_hash['hp'] = building[:build_hp]
    update_hash['building_id'] = building_id
    update_hash['building_hp'] =!building[:build_hp].nil? ? building[:build_hp] : building[:max_hp]
  when nil
    update_hash['building_id'] = building_id
    update_hash['building_hp'] = !building[:build_hp].nil? ? building[:build_hp] : building[:max_hp]
  end

  mysql_update('grid', tile.id, update_hash)

  building[:materials].each do |item, amt|
    user.change_inv(item, -amt)
  end

  msg = building[:build_msg]
  msg += break_attempt(user, building[:tools])

  xp_type = building[:build_xp_type]
  xp_type = :craft if xp_type.nil?
  xp_amt = building[:build_xp]
  user.give_xp(xp_type, xp_amt)

  user.change_ap(-building[:build_ap])

  Message.insert("$ACTOR built #{a_an(building[:name])}", speaker: user, type: 'persistent')
  msg
end

def build_list(user)
  buildings = user.tile.building.improvements
  buildings.delete_if do |building|
    !building[:build_skill].nil? && !user.has_skill?(building[:build_skill])
  end
end

def buildings_in_radius(tile, radius_squared, building)
  if building.is_a?(Array)
    total = 0
    building.each { |b| total += buildings_in_radius(tile, radius_squared, b) }
    return total
  end

  center_x = tile.x
  center_y = tile.y
  radius = Math.sqrt(radius_squared).to_i
  tiles = []
  (-radius..radius).each do |x|
    (-radius..radius).each do |y|
      # ensure location is in circle using pythag
      tiles << Tile.new(center_x + x, center_y + y) if ((x * x) + (y * y)) <= radius_squared
    end
  end

  building_id = lookup_table_row(:building, building, :id)
  tiles.select { |e| e.building_id == building_id }.size
end

def buy_skill(user_id, skill_id)
  user = User.new(user_id)
  if user.level >= Max_Level
    return 'You have reached the current maximum level; you must unlearn ' \
           'some skills before you can learn any more.'
  end
  if !can_buy_skill?(user_id, skill_id)
    return 'You are not able to buy that skill; ' \
           'either you already have it, or lack the required prerequisites.'
  end
  skill = lookup_table_row(:skill, skill_id)
  xp_cost = skill_cost(user.level(skill[:type]))
  xp_field = xp_field(skill[:type])

  user = User.find(user_id)
  if user[xp_field].to_i < xp_cost
    "You do not have sufficient #{lookup_table_row(:skills_renamed, :name, skill[:type])} xp to buy that skill."
  else
    mysql_bounded_update('users', xp_field, user_id, -xp_cost, 0)
    mysql_insert('skills', user_id: user_id, skill_id: skill_id)
    "You have learned the arts of #{lookup_table_row(:skill, skill_id, :name)}."
  end
end

def can_attack_totem?(totem)
  big_buildings = lookup_table(:building).clone
  big_buildings.delete_if do |_name, building|
    building[:settlement_level].nil? && building[:floors].zero?
  end
  big_buildings = big_buildings.keys
  building_amt = buildings_in_radius(totem.tile, 5, big_buildings)

  if building_amt.positive?
    return false, "There are still #{building_amt} large buildings in " \
      'the vicinity. You must destroy all the buildings in the area ' \
      "before you can attack #{totem.name}."
  end

  true
end

def can_build?(user, building)
  tile = user.tile

  return false, "In your dazed state, you can't remember how to build." if user.hp.zero?

  building = lookup_table_row(:building, building) if building.is_a?(Symbol)

  if !user.has_skill?(building[:build_skill])
    return false, "You don't have the required skills " \
      "to build #{a_an(building[:name])}."
  end

  if building[:special] == :terrain
    if tile.terrain != 1 && tile.terrain != 4 && tile.terrain != 24
      return false, "You cannot build #{a_an(building[:name])} here."
    end
  elsif building[:size] == :large
    return false, "You cannot build #{a_an(building[:name])} here." if !lookup_table_row(:terrain, tile.terrain, :build_large?)
  elsif building[:size] == :small
    return false, "You cannot build #{a_an(building[:name])} here." if !lookup_table_row(:terrain, tile.terrain, :build_small?)
  elsif !lookup_table_row(:terrain, tile.terrain, :build_tiny?)
    return false, "You cannot build #{a_an(building[:name])} here."
  end

  if (!building[:prereq].nil? &&
      (tile.building_id != lookup_table_row(:building, building[:prereq], :id))) ||
     (building[:prereq].nil? && (building[:id] != 10) && # 10 = dirt track
      (tile.building_id != 0))
    return false, "You cannot build #{a_an(building[:name])} here."
  end

  if !building[:settlement_level].nil? && tile.settlement.nil?
    return false, a_an(building[:name]).capitalize +
      ' can only be built in an established settlement.'
  end

  if !user.has_item?(building[:tools])
    return false, 'You need ' +
      describe_items_list(building[:tools], 'long') +
      " to build #{a_an(building[:name])}."
  end

  if !user.has_item?(building[:materials])
    return false, 'You need ' +
      describe_items_list(building[:materials], 'long') +
      " to build #{a_an(building[:name])}."
  end

  true
end

def can_buy_skill?(user_id, skill_id)
  user = User.ensure(user_id)
  return false if user.has_skill?(skill_id)

  prereq = lookup_table_row(:skill, skill_id, :prereq)
  prereq.nil? || user.has_skill?(prereq)
end

def can_sell_skill?(user_id, skill_id)
  user = User.ensure(user_id)
  return false if !user.has_skill?(skill_id)

  skill = id_to_key(:skill, skill_id)
  post_reqs = lookup_all_where(:skill, :prereq, skill)
  post_reqs.each do |requirement|
    return false if user.has_skill?(requirement[:id])
  end
  true
end

def can_settle?(tile)
  totems = buildings_in_radius(tile, 400, :totem)
  if totems.positive?
    return false, "There #{is_are(totems)} already #{totems} " \
      'settlements near here; ' \
      'there must be no other totem poles within a 20-tile radius ' \
      'to build a new totem.'
  end

  huts = buildings_in_radius(tile, 5, :hut)
  if huts < 3
    return false, "There #{is_are(totems)} only #{huts} huts near here; " \
      'there must be at least three huts within your field of ' \
      'view (excluding corners) to build a new totem pole.'
  end

  [true, 'This looks like a fine spot to build a settlement. ' \
    'Please choose a name for your new community.']
end

def chat(user, text)
  return "You can't think of anything to say." if text == ''
  return 'Message too long.' if text.length > 255

  Message.insert(CGI.escapeHTML(text), speaker: user, type: 'chat')
  "You shout <i>\"#{CGI.escapeHTML(text)}\"</i> to the whole world."
end

def chop_tree(user)
  user = User.find(user)
  tile = user.tile
  tile_actions = lookup_table_row(:terrain, tile['terrain'], :actions)
  return 'There are no trees here.' if tile_actions.nil? || !tile_actions.include?(:chop_tree)

  return 'You cannot chop down trees while inside.' if !user.outside?

  return 'You need an axe to chop down trees.' if !(user.has_item?(:hand_axe) || user.has_item?(:stone_axe))

  mysql_transaction do
    user.change_ap(-chop_tree_ap(user))
    user.give_xp(:wander, 2)
    user.change_inv(15, +1) # 15 -> log
  end
  Message.insert('$ACTOR chopped down a tree', speaker: user, type: 'persistent')
  msg = 'You chop down a tree, taking the heavy log.'

  if rand < 0.12
    msg << ' The tree cover in this area has been reduced.'
    new_terrain =
      case tile['terrain']
      when '21'
        tile['hp'] == '0' ? 82 : 24
      when '22' then 21
      when '23' then 22
      when '6' then 2
      when '2' then 7
      when '7'
        tile['hp'] == '0' ? 81 : 4
      end
    tile.update(terrain: new_terrain) if new_terrain
  end
  msg
end

def chop_tree_ap(user)
  user = User.ensure(user)
  user.has_skill?(15) ? 4 : 9 # 15 -> lumberjack
end

def craft(user, item_id)
  user = User.ensure(user)
  return "In your dazed state, you can't remember how to craft." if user.hp.zero?

  product = lookup_table_row(:item, item_id)
  return 'That item cannot be crafted.' if product[:craftable] != true

  craft_skill = product[:craft_skill]
  return 'You do not have the required skills to craft that.' if !craft_skill.nil? && !user.has_skill?(craft_skill)

  if !product[:craft_building].nil?
    building = user.tile.building_id
    if lookup_table_row(:building, product[:craft_building], :id) != building
      return 'You must be in the vicinity of ' \
             "#{a_an(lookup_table_row(:building, product[:craft_building], :name))} to " \
             "craft #{a_an(product[:name])}."
    end
  end

  if !user.has_all_items?(product[:tools])
    return "You need #{describe_items_list(product[:tools], 'long')} to build #{a_an(product[:name])}."
  end

  if !user.has_all_items?(product[:materials])
    return 'You need ' +
           describe_items_list(product[:materials], 'long') +
           " to build #{a_an(product[:name])}."
  end

  product[:materials].each do |item, amt|
    user.change_inv(item, -amt)
  end

  xp_type = product[:craft_xp_type]
  xp_type = :craft if xp_type.nil?
  xp_amt = product[:craft_xp]
  user.give_xp(xp_type, xp_amt)
  user.change_ap(-product[:craft_ap])

  craft_amount = product[:craft_amount]
  craft_amount = 1 if craft_amount.nil?
  user.change_inv(item_id, +craft_amount)

  product[:extra_products]&.each do |item, value|
    mysql_change_inv(user, item, +value)
  end
  msg = "You craft #{describe_items(craft_amount, item_id, :long)}."
  msg << break_attempt(user, product[:tools])
end

def craft_list(user_id)
  user = User.ensure(user_id)
  items = lookup_all_where(:item, :craftable, true)
  items.delete_if do |item|
    !item[:craft_skill].nil? && !user.has_skill?(item[:craft_skill])
  end
end

def deal_damage(dmg, target)
  if target.hp > dmg
    field = target.is_a?(Building) ? :building_hp : :hp
    target.update(**{field => (target.hp - dmg)})
    kill = false
  else
    case target.class.name

    when 'User'
      target.update(hp: 0)
      if target.temp_sett_id != 0
        mysql_update('accounts', target.id, temp_sett_id: 0)
        Message.insert('$ACTOR, dazed before the day ended, have lost your pending settlement residency.',
                       speaker: target)
      end

    when 'Animal'
      target.delete

    when 'Building'
      destroy_building(target)
    end

    kill = true
  end
  kill
end

def describe_animals(amount, type, length = :short)
  # example (short) output = '3 wolves' / 'wolf'
  # example (long) output = 'three wolves' / 'a wolf'
  case amount
  when 0
     ''
  when 1
    length == :short ? lookup_table_row(:animal, type, :name) : a_an(lookup_table_row(:animal, type, :name))
  else
    if length == :short
      "#{amount} #{lookup_table_row(:animal, type, :plural)}"
    else
      "#{describe_number(amount)} #{lookup_table_row(:animal, type, :plural)}"
    end
  end
end

def describe_animals_on_tile(x, y)
  animals = mysql_select('animals', x: x, y: y)
  num_animals = animals.count

  if num_animals.positive?
    animals = values_freqs_hash(animals, 'type_id')
    animal_descs = animals.map { |type, amt| describe_animals(amt, type, :long) }
    "#{describe_list(animal_descs).capitalize} #{is_are(num_animals)} here."
  end
end

def describe_craft(item_row)
  craft_amt = item_row[:craft_amount]
  name =
    if !craft_amt.nil? && craft_amt != 0
      describe_items(craft_amt, item_row[:id])
    else
      item_row[:name].capitalize
    end

  name = "Repair #{name}" if item_row[:repair]

  ap_cost = item_row[:craft_ap] || item_row[:build_ap]

  tools = []
  materials = []
  if !item_row[:tools].nil?
    tools = item_row[:tools].map do |tool|
      describe_items(1, tool, 'long')
    end
  end
  materials = item_row[:materials].map { |item, amt| describe_items(amt, item, :short, ' x ') } if !item_row[:materials].nil?
  "#{name} (#{ap_cost}ap, #{(tools + materials).join(', ')})"
end

def describe_items(amount, item, length = :short, infix = ' ')
  case amount.to_i
  when 0
    ''
  when 1
    length == :short ? "1#{infix}#{lookup_table_row(:item, item, :name)}" : a_an(lookup_table_row(:item, item, :name))
  else
    if length == :short
      "#{amount}#{infix}#{lookup_table_row(:item, item, :plural)}"
    else
      "#{describe_number(amount)}#{infix}#{lookup_table_row(:item, item, :plural)}"
    end
  end
end

def describe_items_list(items, length = :short, infix = ' ')
  items ||= []
  item_descs = if items.is_a?(Hash)
                 items.map { |item, amt| describe_items(amt, item, length, infix) }
               else
                 items.map { |item| describe_items(1, item, length, infix) }
               end
  describe_list(item_descs)
end

def describe_list(coll)
  # correctly formats an english list
  # eg -> [1,2,3,4] -> "1, 2, 3 and 4"
  coll = coll.compact
  if coll.size > 1
    "#{coll[0..-2].join(', ')} and #{coll.last}"
  else
    coll.join
  end
end

def describe_location(user_id)
  user = User.new(user_id)
  desc = user.tile.description(user.z).to_s
  desc << " #{describe_animals_on_tile(user.x, user.y)}" if user.z.zero?
  desc << " #{describe_occupants(user.x, user.y, user.z, user_id)}"
end

def describe_number(n)
  n = n.to_i
  (n < 50) ? n.to_words : 'loads of'
end

def describe_occupants(x, y, z, omit = 0)
  occupants = mysql_count('users', { x: x, y: y, z: z, active: 1 }, id: omit)
  return '' if occupants.zero?

  omit = User.ensure(omit)
  show_hp = true if omit.has_skill?(:triage)
  occupant_links = []
  occupants.each do |occupant|
    occupant_links << html_userlink(occupant['id'], occupant['name'], :details, show_hp)
  end
  desc = if occupants.count == 1
           'Standing here is '
         else
           'Standing here are '
         end
  desc << describe_list(occupant_links) << '.'
end

def describe_weapon(item, user_id)
  user = User.new(user_id)
  accuracy = item_stat(item[:id], :accuracy, user)
  dmg = item_stat(item[:id], :effect, user)

  "#{item[:name].capitalize} (#{accuracy}%, #{dmg} dmg)"
end

def destroy_building(building)
  mysql_transaction do
    mysql_insert('messages', x: building.x, y: building.y, z: 0,
                             type: 'persistent', message: "#{building.a.capitalize} was destroyed!")
    mysql_delete('writings', x: building.x, y: building.y)
    mysql_update('users', { x: building.x, y: building.y }, z: 0)
    mysql_update('grid', building.id,
                 building_hp: 0, building_id: 0)
    destroy_settlement(building.tile.settlement) if building.special == :settlement
    if building.special == :walls
      mysql_update('grid', building.id,
                   building_hp: 0, building_id: 0, terrain: 8, hp: 0)
    end
  end
end

def destroy_settlement(settlement)
  mysql_transaction do
    mysql_insert('messages', x: settlement.x, y: settlement.y, z: 0,
                             type: 'persistent', message: "The settlement of #{settlement.name} was destroyed!")
    mysql_update('accounts', { settlement_id: settlement.id }, settlement_id: 0)
    mysql_update('accounts', { temp_sett_id: settlement.id }, temp_sett_id: 0)
    mysql_delete('settlements', settlement.id)
  end
end

def dig(user)
  user = User.ensure(user)
  tile = user.tile

  return 'You would rather not dig a hole in the floor.' if user.inside?
  return 'You cannot dig here.' if !tile.actions.include?(:dig)
  return 'You need a digging stick to dig here.' if !user.has_item?(:digging_stick)

  diggables = lookup_table_row(:terrain, tile.terrain, :dig)
  found_item = random_select(diggables, 100)
  if found_item.nil?
    msg = 'You dig a hole, but find nothing of use.'
    user.change_ap(-2)
  else
    mysql_transaction do
      user.change_inv(found_item, 1)
      user.change_ap(-2)
      user.give_xp(:wander, 1)
    end
    msg = "Digging a hole, you find #{lookup_table_row(:item, found_item, :desc)}."
  end

  msg << " #{break_attempt(user, :digging_stick)}"
end

def dir_to_offset(dir)
  case dir
  when 'NW','Northwest'
     [-1, -1, 0]
  when 'N','North'
     [0, -1, 0]
  when 'NE','Northeast'
     [1, -1, 0]
  when 'W' || 'West'
     [-1, 0, 0]
  when 'E','East'
     [1, 0, 0]
  when 'SW','Southwest'
     [-1, 1, 0]
  when 'S','South'
     [0, 1, 0]
  when 'SE','Southeast'
     [1, 1, 0]
  when 'Enter'
     [0, 0, 1]
  when 'In'
     [0, 0, 1]
  when 'Up'
     [0, 0, 1]
  when 'Down'
     [0, 0, -1]
  when 'Exit'
     [0, 0, -1]
  when 'Out'
     [0, 0, -1]
  else
     [0, 0, 0]
  end
end

def drop(user, item_id, amount)
  return 'You drop nothing.' if item_id.nil?
  return "That's an invalid quantity to drop." if amount.to_i < 1 || amount.to_i > 15

  amt_dropped = -user.change_inv(item_id, -amount.to_i)
  user.tile.change_inv(item_id, +amt_dropped)
  "You drop #{describe_items(amt_dropped, item_id, :long)}."
end

def feed(feeder_id, target_id, item_id)
  target = User.find(target_id)
  item = lookup_table_row(:item, item_id)
  item_desc = a_an(item[:name])

  if target['hunger'].to_i >= Max_Hunger
    return "You're not feeling hungry at the moment." if feeder_id == target_id

    return "You try offering #{item_desc} to #{target['name']}, but they're not hungry."
  end
  feeder_id.change_inv(item_id, -1)
  mysql_bounded_update('users', 'hunger', target_id, +1, Max_Hunger)
  mysql_bounded_update('users', 'maxhp', target_id, +3, Max_HP)

  if feeder_id == target_id
    "You eat #{item_desc}."
  else
    Message.insert("$ACTOR fed $TARGET #{item_desc}", speaker: feeder_id, target: target_id)
    "You feed #{item_desc} to #{target['name']}."
  end
end

def fill(user)
  tile = user.tile
  return 'You cannot fill a pot here.' if !tile.actions.include?(:fill)
  return "You don't have any container to fill with water." if !user.has_item?(:pot)

  user.change_inv(:water_pot, 1)
  user.change_inv(:pot, -1)
  user.change_ap(-1)
  'You fill a pot with water.'
end

def give(giver, receiver, amount, item_id)
  return '' if !receiver.exists?

  return 'ERROR: Invalid user.' if giver.nil? || receiver.nil?

  return "#{receiver.name} is not in the vicinity." if !same_location?(giver, receiver)

  return "You cannot leave items in #{receiver.name}." if receiver.is_a?(Building) && !receiver.item_storage?

  if receiver.is_a?(User)
    return "#{receiver.name} already has as much as they can carry." if receiver.weight >= Max_Weight
  end

  return "You give nothing to #{receiver.name}." if item_id.nil?

  return "That's an invalid quantity to give." if amount.to_i < 1 || amount.to_i > 15

  amt_given = -giver.change_inv(item_id, -amount.to_i)

  items_desc = describe_items(amt_given, item_id, :long)

  receiver.change_inv(item_id, amt_given)
  if receiver.is_a?(Building)
    Message.insert("$ACTOR dropped #{items_desc} in the stockpile", speaker: giver.id, type: 'persistent')
  else
    Message.insert("$ACTOR gave #{items_desc} to $TARGET", speaker: giver.id, target: receiver.id)
  end

  giver.change_ap(-1)
  "You give #{items_desc} to #{receiver.name}."
end

def habitats(animal)
  habitat_types = lookup_table_row(:animal, animal, :habitats)
  habitats = habitat_types.collect do |type|
    matches = lookup_all_where(:terrain, :class, type)
    matches&.collect { |match| match[:id] }
  end
  habitats.flatten!
end

def harvest(user)
  return 'You must wait until Autumn before the crops can be harvested.' if season != :Autumn

  return 'You have not yet discovered the secrets of agriculture.' if !user.has_skill?(:agriculture)

  tile = user.tile.mysql
  return 'There is nothing to harvest here.' if tile['terrain'] != '91' # 91 = wheat field

  if !user.has_item?(:hand_axe) &&
     !user.has_item?(:stone_axe) &&
     !user.has_item?(:stone_sickle)
    return 'You need a sickle or an axe to harvest crops.'
  end

  user.change_ap(-harvest_ap(user))
  user.give_xp(:herbal, 4)
  harvest_size = -mysql_bounded_update('grid', 'building_hp',
                                       { x: user.x, y: user.y }, -10, 0)
  mysql_update('grid', { x: user.x, y: user.y }, terrain: 9) if mysql_tile(user.x, user.y)['building_hp'] == '0'
  user.change_inv(21, +harvest_size) # 21 - wheat
  Message.insert("$ACTOR harvested #{harvest_size} measures of wheat from the field", speaker: user, type: 'persistent')
  "You harvest #{harvest_size} measures of wheat from the field."
end

def harvest_ap(user)
  if user.has_item?(:stone_sickle)
    8
  else
    16
  end
end

def heal(healer, target, item_id)
  item = lookup_table_row(:item, item_id)
  item_desc = a_an(item[:name])

  if target.hp >= target.maxhp
    return "You're already at full health." if healer == target

    return "#{target.name} is already at full health."
  end

  if target.hp.zero?
    return you_or_her(healer.id, target.id, 'You', false) +
           ' are currently dazed and must be revived before healing items ' \
           'have any effect.'
  end

  healer.change_inv(item_id, -1)
  hp_healed = mysql_bounded_update('users', 'hp',
                                   target.id, +item_stat(item_id, :effect, healer), target.maxhp)
  healer.change_ap(-1)
  xp = (hp_healed.to_f / 2) + 1
  healer.give_xp(:herbal, xp)

  if healer == target
    "You use #{item_desc} on yourself, healing #{hp_healed} hp."
  else
    Message.insert("$ACTOR used #{item_desc} on $TARGET, healing #{hp_healed} hp.",
                   speaker: healer, target: target)
    "You use #{item_desc} on #{target.name}, " \
      "healing #{hp_healed} hp of damage. " \
      "They now have #{target.hp + hp_healed} hp."
  end
end

def hours_mins_to_daytick
  # unfinished!
  unix_t = Time.now.to_i
  seconds_in_day = (3600 * 24)
  secs_past_midnight = unix_t - ((unix_t / seconds_in_day) * day_secs)
  ((seconds_in_day - secs_past_midnight) / 3600)
end

def http(url)
  strip_http_re = %r{(http:\/\/)?(.*)}
  "http://#{strip_http_re.match(url)[2]}"
end

def id_to_key(table, id)
  id = id.to_i if id.is_a? String
  match = lookup_table(table).detect { |_key, value| value[:id] == id }
  match[0]
end

def insert_breaks(str)
  str = str.gsub(/\r/, '<br>')
  str.delete("\n")
end

def insert_names(str, actor_id, target_id, user_id = 0, link = true)
  if str.slice(0, 6) == '$ACTOR'
    # capitalise 'you' at start of msg
    str = str.sub(/\$ACTOR/, you_or_him(user_id, actor_id, 'You', link))
  end
  # capitalise 'you' after '. '
  str = str.gsub(
    /(\. *)\$ACTOR/,
    '\1' + you_or_him(user_id, actor_id, 'You', link)
  )
  str = str.gsub(/\$ACTOR/, you_or_him(user_id, actor_id, 'you', link))

  # if target_id is an integer, replace $target with user of that id
  # otherwise, replace $target with target_id
  # (so we can pass, eg, "the deer" as a target)
  if target_id.is_a?(Integer) && target_id != 0
    str = str.gsub(
      /(\. *)\$TARGET/,
      '\1' + you_or_him(user_id, target_id, 'You', link)
    )
    str = str.gsub(/\$TARGET/, you_or_him(user_id, target_id, 'you', link))
  else
    str = str.gsub(/(\. *)\$TARGET/, '\1' + target_id.to_s)
    str = str.gsub(/\$TARGET/, target_id.to_s)
  end
  str
end

def ip_hit(user_id = 0, hit = 10)
  return 0 if user_id != 0 && User.new(user_id).donated?

  ip = $cgi.remote_addr
  ip_row = mysql_row('ips', ip: ip)
  if ip_row.nil?
    mysql_insert('ips', ip: ip, hits: hit, user_id: user_id)
    $ip_hits = hit
  else
    mysql_update('ips', { ip: ip }, hits: (ip_row['hits'].to_i + hit))
    $ip_hits = ip_row['hits'].to_i + hit
  end
  $ip_hits
end

def is_are(num)
  num == 1 ? 'is' : 'are'
end

def item_building_bonus(item_id, stat, user)
  user = User.ensure(user)
  building = user.tile.building
  return 1 if !building.exists?
  return 1 if building.use_skill.nil?
  return 1 if !user.has_skill?(building.use_skill)

  item_type = lookup_table_row :item, item_id, :use
  return 1 if item_type.nil?

  bonus_hash = case stat
               when :effect then building.effect_bonus
               when :craft_ap then building.craft_ap_bonus
               when :accuracy then building.accuracy_bonus
               end
  return 1 if bonus_hash.nil?

  bonus = bonus_hash[item_type]
  return 1 if bonus.nil?

  bonus
end

STAT_DEFAULTS = {
  ap_cost: 1,
  effect: 0,
  accuracy: 100
}.freeze
def item_stat(item_id, stat, user)
  user = User.ensure(user)
  multiplier = item_building_bonus item_id, stat, user
  data = lookup_table_row(:item, item_id, stat)
  return (data * multiplier).floor if data.is_a?(Integer)

  if data.is_a?(Hash)
    # data should be a hash of {skill => value}, find max/min value
    user_skills = data.delete_if { |skill, _value| !user.has_skill?(skill) }
    data = if stat == :ap_cost
             user_skills.values.min
           else
             user_skills.values.max
           end
    return (data * multiplier).floor
  end

  STAT_DEFAULTS[stat].to_i if data.nil?
end

def join(user)
  tile = user.tile
  building = tile.building
  return 'You must be at a totem pole to join a settlement.' if !building.exists?
  return 'You must be at a totem pole to join a settlement.' if !building.actions.include?(:join)
  return "You are already a resident of #{tile.settlement.name}." if user.settlement_id == tile.settlement_id
  if user.temp_sett_id == tile.settlement_id
    return "You are already on your way to becoming a resident of #{tile.settlement.name}."
  end
  return 'You cannot join a settlement while you are dazed.' if user.hp <= 0
  if (user.settlement_id != 0) || (user.temp_sett_id != 0)
    return 'You must relinquish your ties to other settlements before you can join.'
  end

  if tile.settlement.population.zero?
    mysql_update('accounts', user.id,
                 settlement_id: tile.settlement_id)
    msg = "You pledge allegiance to #{tile.settlement.name}. As its only resident, you declare yourself its leader."
    mysql_update('accounts', user.id, vote: user.id)
    mysql_update('settlements', tile.settlement_id, leader_id: user.id)
  else
    mysql_update('accounts', user.id,
                 temp_sett_id: tile.settlement_id)
    msg = "You pledge allegiance to #{tile.settlement.name}. You must survive the day to be entitled to its privileges."
  end
  mysql_update('accounts', user.id,
               when_sett_joined: :Now)
  user.id.change_ap(-25)
  Message.insert('$ACTOR made a pledge to join this settlement.', speaker: user, type: 'persistent')
  msg += " You are no longer a resident of #{user.settlement.name}." if user.settlement_id != 0
  msg
end

def leave(user)
  return 'You are not currently a member of any settlement.' if user.settlement_id.zero? && user.temp_sett_id.zero?

  if user.settlement_id != 0
    if user.id == user.settlement.leader_id # Non-residents don't get to be leader :P
      mysql_update('settlements', user.settlement_id,
                   leader_id: 0)
    end
  end
  mysql_update('accounts', user.id,
               settlement_id: 0)
  if user.temp_sett_id != 0
    mysql_update('accounts', user.id,
                 temp_sett_id: 0)
    return 'You give up your attempt to gain settlement residency.'
  end
  "You are no longer a resident of #{user.settlement.name}."
end

def logout(user)
  # delete cookies
  $cookie.expires = Time.now

  # undo ip hit cost
  ip_hit(user.id, -10)

  # redirect to homepage
  $header['Location'] = './index.cgi'
end


def move(user, x, y, z)
  x = x.to_i
  y = y.to_i
  z = z.to_i
  if (![-1, 0, 1].include? x) ||
     (![-1, 0, 1].include? y) ||
     (![-1, 0, 1].include? z)
    raise ArgumentError, 'bad offset'
  end

  current_tile = user.tile
  return 'You are over-encumbered and cannot move.' if user.weight >= Max_Weight

  if z.zero?
    # move player in cardinal direction, if player is not in building
    # includes fix for 'stuck in stockpile bug'
    if user.z != 0 && user.tile.building.exists? && user.tile.building.floors != 0
      "You must leave the building before you can move #{offset_to_dir(x, y, z, :long)}."
    else
      # get ap cost for target tile
      target_x = user.x + x
      target_y = user.y + y
      target_tile = Tile.new(target_x, target_y)
      targ_sett = target_tile.settlement
      ap_cost = ap_cost(target_tile.terrain, current_tile.terrain, user.id, targ_sett)
      if !ap_cost.nil?
        mysql_transaction do
          user.change_ap(-ap_cost)
          xp = lookup_table_row(:terrain, target_tile.terrain, :xp)
          if !xp.nil?
            xp = rand_to_i(xp)
            user.give_xp(:wander, xp)
          end
          user.update(x: target_x, y: target_y, z: 0)
        end
        "You head #{offset_to_dir(x, y, z, :long)}."
      else
        'You cannot move there.'
      end
    end
  else
    target_z = user.z + z
    if valid_location?(user.x, user.y, target_z)
      mysql_transaction do
        user.update(z: target_z)
        user.change_ap(-1)
      end
      case target_z
      when 0 then 'You head outside.'
      when 1 then 'You head inside.'
      else 'You move to floor ' + target_z.to_s
      end
    else
      'You cannot move there.'
    end
  end
end

def move_animal(animal)
  animal = Animal.ensure(animal)
  # tile = Tile.new(animal['x'], animal['y'])

  return false if animal.immobile

  habitats = habitats(animal.type_id)
  8.times do
    dir = random_dir
    x, y = dir_to_offset(dir)
    dest_tile = Tile.new(animal.x + x, animal.y + y)
    if habitats.include?(dest_tile['terrain'].to_i)
      animal.update(x: (animal.x + x), y: (animal.y + y))
      return true
    end
  end
  false
end

def msg_dazed(player)
  if player['hp'].to_i.zero?
    'You are dazed. Until you are revived, ' \
      'your actions are limited and you will regain AP more slowly.'
  else
    ''
  end
end

def msg_tired(player)
  if player['ap'].to_f < 1
    'Totally exhausted, you collapse where you stand.'
  elsif $ip_hits > 3300
    "<span class='ipwarning'>" \
      'You have exceeded your IP limit for the day (enough for three characters). ' \
      'Please wait until tomorrow to play again.</span>'
  elsif $ip_hits > 3150 && $ip_hits < 3301
    "<br><span class='ipwarning'>" \
      'You are nearing your IP limit for the day. ' \
      'You might want to finish up what you are doing ' \
      'or get somewhere safe.</span>'
  else
    ''
  end
end

def msg_no_ap(user_id)
  player = User.find(user_id)
  hours = ((0 - player['ap'].to_f) / ap_recovery(user_id)).to_i

  msg = 'You must wait for your AP to recover (about '
  msg << "#{hours} hours" if hours != 0
  msg << "#{minutes_to_hour} minutes) before you can act."
end

def msg_no_ip
  min = Time.now.min
  min = "0#{min}" if min < 10
  hour = Time.now.hour
  hour = "0#{hour}" if hour < 10
  "You have used up your IP hits for the day. IPs reset around midnight server time. It is currently #{hour}:#{min}."
end

def ocarina(user, target, _item_id)
  user = User.ensure(user)
  user.change_ap(-0.2)
  if user == target
    Message.insert('$ACTOR played a lively melody on the ocarina',
                   speaker: user, type: 'visible_all')

    if rand < 0.3
      'You play a lively melody on your ocarina. ' \
        'A whirlwind appears and attempts to carry you off, ' \
        "but you're too heavy."
    else
      'You play a lively melody on your ocarina.'
    end
  else
    Message.insert('$ACTOR played a lively melody on the ocarina for $TARGET',
                   speaker: user, target: target, type: 'visible_all')
    'You play a lively melody on your ocarina ' \
      "for #{target.name}."
  end
end

def quarry(user)
  user = User.ensure(user)
  return 'You cannot quarry here.' if !user.tile.actions.include?(:quarry)
  return 'You do not have the required skills to quarry.' if !user.has_skill?(:quarrying)
  return 'You need a pick to quarry here.' if !(user.has_item?(:bone_pick) || user.has_item?(:ivory_pick))

  user.change_ap(-4)
  if rand < 0.5
    msg = 'Chipping away at the rock face, you manage to work free a large boulder.'
    user.change_inv(:boulder, 1)
    user.give_xp(:craft, 2.5)
  else
    msg = 'You chip away at the rock face, but fail to remove anything.'
  end
  msg + if user.has_item?(:ivory_pick)
          " #{break_attempt(user, :ivory_pick)}"
        else
          " #{break_attempt(user, :bone_pick)}"
        end
end

def random_select(hash, denom = 0)
  # when passed a hash of the form
  # {option1 => probability, option2 => probability, etc}
  # returns one of the options
  # if denom is set, chance of option1 being returned
  # equals probality1/denom
  # if not, chance of option1 being returned equals
  # probability1/sum of probabilities

  denom = hash.values.sum if denom.zero?
  rnd = rand * denom
  selected = nil
  hash.each do |option, chance|
    # puts "Chance: " + chance.to_s + " Rnd: " + rnd.to_s
    if chance > rnd
      selected = option
      break
    else
      rnd -= chance
    end
  end
  selected
end

def repair(user)
  user = User.ensure(user)
  building = user.tile.building.repair

  if !user.has_skill?(building[:build_skill])
    return "You don't have the required skills " \
           "to repair the #{building[:name]}."
  end

  if !user.has_item?(building[:tools])
    return 'You need ' +
           describe_items_list(building[:tools], 'long') +
           " to repair the #{building[:name]}."
  end

  if !user.has_item?(building[:materials])
    return 'You need ' +
           describe_items_list(building[:materials], 'long') +
           " to repair the #{building[:name]}."
  end

  return "The #{building[:name]} does not need any repairs." if !user.tile.building_hp < building[:max_hp]

  return 'Use the Add Fuel button instead.' if building[:name] == 'campfire'

  mysql_update('grid', user.tile.id,
               building_hp: building[:max_hp])

  building[:materials].each do |item, amt|
    user.change_inv(item, -amt)
  end

  msg = "You repair the #{building[:name]}. "
  msg += break_attempt(user, building[:tools])

  xp_type = building[:build_xp_type]
  xp_type = :craft if xp_type.nil?
  xp_amt = building[:build_xp]
  user.give_xp(xp_type, xp_amt)

  user.change_ap(-building[:build_ap])

  Message.insert("$ACTOR repaired #{a_an(building[:name])}", speaker: user, type: 'persistent')
  msg
end

def revive(healer_id, target_id, item_id)
  healer = User.new healer_id
  target = User.new target_id
  item = lookup_table_row(:item, item_id)
  item_desc = a_an(item[:name])
  return "You can't revive yourself. Especially when you're not dazed." if (healer == target) && (healer.hp != 0)
  return "You can't revive yourself. You'll have to find someone else to revive you." if healer == target

  if target.hp != 0
    return "You try using #{item_desc} on " \
           "#{target.name}, however it doesn't have any effect. " \
           'Try using it on someone who has been knocked out.'
  end

  if healer.hp.zero?
    return "You try using #{item_desc} on " \
           "#{target.name} with little success. " \
           "You can't revive others while you're dazed."
  end

  tile = Tile.new(healer.x, healer.y)
  if tile.settlement != healer.settlement && !tile.settlement.nil?
    return 'You are not a member of ' + tile.settlement.name + ', and cannot perform revives within its boundries.'
  end

  return "#{target.name} is starved. They need a little food before herbal remedies will do any good." if target.hunger.zero?

  hp_healed = mysql_bounded_update('users', 'hp',
                                   target.id, +item_stat(item_id, :effect, healer), target.maxhp)
  xp = (hp_healed.to_f / 2).ceil + 10
  mysql_transaction do
    mysql_update('users', target_id, hp: hp_healed)
    healer_id.change_ap(-10)
    healer.give_xp(:herbal, xp)
    healer_id.change_inv(item_id, -1)
    mysql_change_stat(healer, 'revives', +1)
    mysql_update('accounts', target_id, last_revive: :Today)
  end
  Message.insert("$ACTOR used #{item_desc} on $TARGET, reviving them from their daze.",
                 speaker: healer_id, target: target_id)
  "You use #{item_desc} on #{target.name}, reviving them from their daze. " \
    "They now have #{hp_healed} hp."
end

def same_location?(a, b)
  # this should be deleted after OOP refactoring!
  return a['x'] == b['x'] && a['y'] == b['y'] && a['z'] == b['z'] if a.is_a?(Hash) && b.is_a?(Hash)

  if !(a.exists? || !b.exists?)
    puts 'One of the arguments to same_location? refers to an invalid entity.'
    return false
  end

  return a.x == b.x && a.y == b.y if a.is_a?(Building) || b.is_a?(Building)

  a.x == b.x && a.y == b.y && a.z == b.z
end

def say(speaker, message, volume, target = nil)
  return 'Error. Try again.' if volume != 'Talk' && volume != 'Shout' && volume != 'Whisper'

  return 'Message too long.' if message.length > 255

  # check for '/me'
  if message.slice(0, 3) == '/me'
    message = message.gsub(%r{\/me}, '$ACTOR')
    message = message.gsub(%r{\/you}, '$TARGET')
    volume = 'slash_me'
  end
  volume.downcase!

  # if there's a target, check they're nearby
  return "#{target.name} is not in the vicinity." if target.exists? && !same_location?(speaker, target)

  return "You can't think of anything to say." if message == ''

  message = CGI.escapeHTML(message)
  speaker.change_ap(-0.2)
  Message.insert(message, speaker: speaker, target: target, type: volume)

  # insert 8 distance messages if shouting
  if volume == 'shout'
    speaker.change_ap(-2)
    dirs = %w[NW N NE E SE S SW W]
    dirs.each do |dir|
      x, y, z = dir_to_offset(dir)
      mysql_insert('messages',
                   speaker_id: speaker.id, message: message, type: 'distant',
                   x: (speaker.x + x), y: (speaker.y + y),
                   z: (speaker.z + z))
    end
  end

  # work out display
  if volume == 'slash_me'
    target_id = target.exists? ? target.id : 0
    insert_names(message, speaker.id, target_id, speaker.id)
  else
    volume = 'say' if volume == 'talk'
    "You #{volume} <i>\"#{message}\"</i>" +
      (target.exists? ? " to #{target.name}." : '')
  end
end

def search(user)
  tile = user.tile

  user.change_ap(-1)

  search = lookup_table_row(:terrain, tile.terrain, :search)

  return 'You look around the area, but find nothing of use.' if user.z.zero? && (tile.terrain == 99) # searching in ruins
  return 'You look around the building, but find nothing of use.' if (user.z != 0) && (tile.terrain != 99)

  return 'There appears to be nothing to find here.' if search.nil?

  items = search.clone
  # modify search rates based on season
  items.collect do |item, odds|
    season_mod = lookup_table_row(:item, item, season)
    # puts season_mod
    items[item] = odds * season_mod if !season_mod.nil?
    # puts "Item: #{item} #{items[item]}%"
  end
  case tile.hp
  when 0
    items.clear
  when 1
    items.collect { |item, odds| items[item] = odds * 0.5 }
  when 2
    items.collect { |item, odds| items[item] = odds * 0.75 }
  end
  total_odds = items.values.sum

  tile_change = user.tile.mysql
  if !user.has_skill?(:foraging)
    hp_msg =
      case total_odds
      when 0
        if tile_change['terrain'] == '1'
          mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 8)
        elsif tile_change['terrain'] == '4'
          mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 81)
        elsif tile_change['terrain'] == '24'
          mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 82)
        end
        'This area appears to have been picked clean.'
      else
        ''
      end
  else
    hp_msg = case total_odds
             when 0
               if tile_change['terrain'] == '1'
                 mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 8)
               elsif tile_change['terrain'] == '4'
                 mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 81)
               elsif tile_change['terrain'] == '24'
                 mysql_update('grid', { x: tile_change['x'], y: tile_change['y'] }, terrain: 82)
               end
               'This area appears to have been picked clean.'
             when (0..10)
               'This area appears to have very limited resources,'
             when (10..20)
               'This area appears to have limited resources,'
             when (20..30)
               'This area appears to have moderate resources,'
             when (30..40)
               'This area appears to have abundant resources,'
             when (40..200)
               'This area appears to have very abundant resources,'
             else
               'You just hit the motherlode. This place is rich,'
             end
    case tile.hp
    when 0
      # nothing
    when 1
      hp_msg << ' and is below average for this time of year.'
    when 2
      hp_msg << ' and is roughly average for this time of year.'
    else
      hp_msg << ' and is above average for this time of year.'
    end
  end

  found_item = random_select(items, 100)
  if found_item.nil?
    msg = search_hidden_items(user)
    msg = 'Searching the area, you find nothing of use.' if msg.nil?
    return msg + ' ' + hp_msg
  end
  return found_item if found_item.is_a?(String)

  mysql_bounded_update('grid', 'hp', tile.id, -1, 0) if rand < Search_Dmg_Chance
  user.change_inv(found_item, +1)
  user.give_xp(:wander, 1)
  'Searching the area, you find ' +
    lookup_table_row(:item, found_item, :desc) + '. ' + hp_msg
end

def search_hidden_items(user)
  tile = user.tile
  return nil if tile.building.exists? && tile.building.item_storage?

  item_rows = mysql_select('stockpiles', tile.id, amount: 0)
  item_amts = {}
  item_rows.each do |row|
    item_amts[row['item_id'].to_i] = row['amount'].to_i
  end
  found_item = random_select(item_amts, 100)
  return nil if found_item.nil?

  amount_found = -tile.change_inv(found_item, -10)
  user.change_inv(found_item, amount_found)
  'Searching the area, you find ' +
    describe_items(amount_found, found_item, :long) +
    ' which someone has abandoned.'
end

def sell_skill(user_id, skill_id)
  if !can_sell_skill?(user_id, skill_id)
    return "You cannot sell #{lookup_table_row(:skill, skill_id, :name)} " \
           'until you have sold all the skills that come after it.'
  end

  mysql_delete('skills', user_id: user_id, skill_id: skill_id)
  'A wise man once said <i>"Everything new I learn pushes some old stuff out ' \
    'of my brain".</i>  You have forgetten the arts of ' \
    "#{lookup_table_row(:skill, skill_id, :name)}."
end

def settle(user, settlement_name)
  user = User.ensure(user)
  tile = user.tile
  can_settle, settle_msg = can_settle?(tile)
  return settle_msg if !can_settle

  can_build, build_msg = can_build?(user, :totem)
  return build_msg if !can_build

  return 'Your settlement name must be at least two characters.' if $cgi['text'].length < 2
  return 'Your settlement name must not contain invalid characters.' if $cgi['text'] !~ /^\s?[a-zA-Z0-9 .\-']*\s?$/
  return 'Your settlement name must not have spaces at the beginning or end.' if $cgi['text'] != $cgi['text'].strip
  return 'There is already a settlement of that name.' if !mysql_row('settlements', name: settlement_name).nil?

  user.change_inv(:log, -1)
  user.change_ap(-30)
  mysql_update('grid', tile.id, building_id: 4, building_hp: 30) # 4 -> totem pole
  mysql_insert('settlements',
               name: settlement_name, x: tile.x, y: tile.y, founded: :Today, leader_id: user.id)
  mysql_update('accounts', user.id,
               settlement_id: tile.settlement_id, vote: user.id, when_sett_joined: :Now)
  Message.insert("$ACTOR established the settlement of #{settlement_name}", speaker: user, type: 'persistent')

  "You have established the settlement of #{settlement_name}. " \
    'May it grow and prosper.'
end

def sow(user, item_id)
  user = User.ensure(user)

  return 'Crops can only be planted in Spring.' if season != :Spring

  return 'You have not yet discovered the secrets of agriculture.' if !user.has_skill?(:agriculture)

  tile = user.tile.mysql
  return 'You cannot plant anything here.' if tile['terrain'] != '9' # 9 = empty field

  item = lookup_table_row(:item, item_id)
  return "You cannot plant #{item[:plural]}." if item[:plantable] != true

  return "You must have at least ten #{item[:plural]} to plant a field." if user.item_count(item_id) < 10

  # possibly decrease tile fertility
  if tile['hp'] > '3'
    mysql_bounded_update('grid', 'hp', { x: tile['x'], y: tile['y'] }, -1, 0)
  elsif rand(5) <= 1
    mysql_bounded_update('grid', 'hp', { x: tile['x'], y: tile['y'] }, -1, 0)
    if tile['hp'] <= '1'
      mysql_update('grid', { x: tile['x'], y: tile['y'] }, terrain: 8)
      return 'This field has been overfarmed; ' \
             'no crops can be grown here until the land recovers.'
    end
    message = ' The soil seems less fertile than last year.'
  end

  mysql_update('grid', { x: tile['x'], y: tile['y'] }, terrain: 91, building_hp: 0)
  user.change_inv(item_id, -10)
  user.change_ap(-15)
  user.give_xp(:herbal, 5)
  Message.insert('$ACTOR sowed the field with wheat', speaker: user, type: 'persistent')

  "You sow the field with #{item[:plural]}.#{message}"
end

def stockpile_has_item?(x, y, item_id)
  stockpile_item_amount(x, y, item_id).positive?
end

def stockpile_item_amount(x, y, item_id)
  query = "SELECT amount FROM `stockpiles` #{mysql_where(x: x, y: y, item_id: item_id)}"
  result = db.query(query)
  if result.count.positive?
    result.first['amount'].to_i # = result['amount']
  else
    0
  end
end

def take(user_id, amount, item_id)
  user = User.new(user_id)
  stockpile = user.tile.building
  return 'There is nothing you can take here.' if !stockpile.item_storage?

  return 'You take nothing.' if item_id.nil?

  return "You can't take items while dazed." if user.hp.zero?

  return 'You already have as much as you can carry.' if user.weight >= Max_Weight

  stockpile_settlement = user.tile.settlement
  if stockpile_settlement && (stockpile_settlement != user.settlement)
    return "You are not a citizen of #{stockpile_settlement.name}, " \
           'and cannot take items from their stockpile.'
  end

  return "That's an invalid quantity to take." if amount.to_i < 1 || amount.to_i > 5

  amt_taken = -stockpile.change_inv(item_id, -amount.to_i)
  user_id.change_inv(item_id, +amt_taken)
  if amt_taken.zero?
    return "There aren't any #{lookup_table_row(:item, item_id, :plural)} " \
           'in the stockpile.'
  end

  items_desc = describe_items(amt_taken, item_id, :long)
  user.change_ap(-1)
  Message.insert("$ACTOR took #{items_desc} from the stockpile", speaker: user_id, type: 'persistent')
  "You take #{items_desc} from the stockpile."
end

def tile_dir(user, tile)
  # What direction is tile from user?

  x_offset = tile.x - user.x
  y_offset = tile.y - user.y

  if user.z.zero?
    return offset_to_dir(x_offset, y_offset, 0) if user.tile != tile

    valid_location?(tile.x, tile.y, 1) ? 'Enter' : nil
  else
    user.tile == tile ? 'Exit' : nil
  end
end

def transfer_frags(attacker, target)
  frags = (target.frags / 2.0).ceil
  mysql_bounded_update('accounts', 'frags', attacker.id, +frags)
  mysql_bounded_update('accounts', 'frags', target.id, -frags, 0)
  if frags != 0
    "$TARGET lost #{describe_number(frags)} " \
      'frags; they have been transferred to $ACTOR.'
  else
    ''
  end
end

def use(user, target, item_id)
  target = user if !target.exists?

  return "That person isn't in the vicinity." if !same_location?(user, target)

  item = lookup_table_row(:item, item_id)
  return 'Nothing happens.' if item.nil?
  return "You don't have any #{item[:plural]}." if !user.has_item?(item_id)

  return item[:use] if item[:use].is_a? String

  item_desc = a_an(item[:name])
  case item[:use]
  when nil
    "You try using #{item_desc}, but it doesn't seem to achieve much."
  when :weapon
    "Use the 'Attack' button to attack."
  when :food
    feed(user.id, target.id, item_id)
  when :heal
    heal(user, target, item_id)
  when :noobcake
    if target.level > 1
      if user == target
        "Suddenly the sickly sweet noobcakes don't seem quite so tempting anymore. Try finding a different source of food."
      else
        "You offer a noobcake to #{target.name}. They wrinkle their nose in disgust."
      end
    else
      feed(user.id, target.id, item_id) +
        if user == target
          " You particularly enjoy the sugary frosting - it's decorated with a picture of a cuddly bear surrounded by hearts."
        else
          ''
        end
    end
  when :ocarina
    ocarina(user, target, item_id)
  when :revive
    revive(user.id, target.id, item_id)
  end
end

def user_actions(user)
  # returns an array containing the forms to display for user
  tile = user.tile
  actions = []
  if user.can_act?
    if user.hp.positive?
      actions << %i[attack build craft]
      actions << :write if tile.building_id != 0

      building_forms = lookup_table_row(:building, tile.building_id, :actions) || []
      actions << building_forms

      tile_forms = lookup_table_row(:terrain, tile.terrain, :actions) || []
      actions << tile_forms
    else
      actions << :offer
    end
    actions << %i[search give use drop speak]
  elsif user.ap < 1
    actions << :no_ap
  else
    actions << :no_ip
  end
  actions.flatten.compact
end

def valid_location?(x_loc, y_loc, floor)
  tile = Tile.new(x_loc, y_loc)
  floors = lookup_table_row(:building, tile['building_id'], :floors).to_i
  (0..floors).cover?(floor)
end

def vote(voter, candidate)
  return 'You are not currently a member of any settlement.' if voter.settlement.nil? && voter.temp_sett_id.zero?

  if candidate.id.zero?
    mysql_update('accounts', voter.id,
                 vote: candidate.id)
    return 'As none of the candidates suit your fancy, you choose to support no one.'
  end

  return 'You cannot support that person.' if candidate.settlement.nil?

  if voter.settlement != candidate.settlement && voter.temp_sett_id != candidate.settlement.id
    return 'You cannot support that person.'
  end

  mysql_update('accounts', voter.id, vote: candidate.id)
  "You pledge your support for <b>#{candidate.name}</b> as #{candidate.settlement.title} of #{candidate.settlement.name}."
end

def water(user)
  tile = user.tile
  return 'You cannot water here.' if !tile.actions.include?(:water)
  return 'You dont have any water.' if !user.has_item?(:water_pot)
  return "You don't need to water at this time of year." if %i[Fall Winter].include?(season)

  growth = ((tile.hp + 1) / 3).to_i + 4 # 5 at 2 or 3 hp, 4 at 1 hp

  mysql_bounded_update('grid', 'building_hp', tile.id, +growth)
  mysql_bounded_update('grid', 'terrain', tile.id, 1) # change tile to "watered field"
  user.change_inv(:water_pot, -1)
  user.change_inv(:pot, +1)
  user.change_ap(-1)
  user.give_xp(:herbal, 1)

  'You pour a pot of water on the field. ' \
    'You can almost hear the wheat growing.'
end

def write(user, msg)
  building = Building.new(user.x, user.y)
  return 'There is no building to write on in the vicinity.' if !building.exists?

  return "You don't have the cognizance to write while dazed." if user.hp.zero?

  return "You cannot write on #{building.a}." if building.unwritable

  if !user.has_item?(:hand_axe) && !user.has_item?(:stone_carpentry)
    return ' You need a hand axe or a set of stone carpentry tools ' \
           'to write on the building.'
  end

  user.change_ap(-3)
  msg = CGI.escapeHTML(msg)
  # check for existing messages
  if mysql_row('writings', x: user.x, y: user.y, z: user.z).nil?
    mysql_insert('writings',
                 x: user.x, y: user.y, z: user.z, message: msg)
  else
    mysql_update('writings',
                 { x: user.x, y: user.y, z: user.z }, message: msg)
  end

  Message.insert("$ACTOR wrote \"#{msg}\" on #{building.a}", speaker: user, type: 'persistent')
  "You write \"#{msg}\" on #{building.name}."
end

