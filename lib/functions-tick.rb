def tick_campfires
  puts '<li>Campfires burned!</li><ul>'
  campfire_tiles = mysql_select('grid', building_id: 5)
  campfire_tiles.each do |tile|
    next unless rand(2).zero?

    puts "<li>hp #{tile['building_hp']}"
    if tile['building_hp'].to_i <= 1
      mysql_update('grid', { x: tile['x'], y: tile['y'] },
                   building_id: 0, building_hp: 0)
      mysql_insert('messages', x: tile['x'], y: tile['y'], z: '0',
                               type: 'game',
                               message: 'The campfire burned away to nothing')

    else
      mysql_update('grid', { x: tile['x'], y: tile['y'] },
                   building_hp: (tile['building_hp'].to_i - 1))
      if tile['building_hp'] == '5'
        mysql_insert('messages',  x: tile['x'], y: tile['y'], z: '0',
                                  type: 'game',
                                  message: 'The campfire began to get low')
      end
    end
  end
  puts "</ul>"
end

def tick_change_leader
  result = mysql_select_all('settlements')
  settlements = []
  result.each { |row| settlements << Settlement.new(row['id']) }
  settlements.each do |settlement|
    leader = settlement.inhabitants.max_by(&:supporters)
    leader_id = (leader.nil? || leader.supporters.zero?) ? 0 : leader.mysql_id
    mysql_update('settlements', settlement.mysql_id, leader_id: leader_id)
    puts "#{leader.name} (#{leader_id}) " \
         "is now #{settlement.title} of #{settlement.name}."
  end
  'Leaders changed!'
end

def tick_settlement_membership
  result = mysql_select('accounts', { settlement_id: 0 }, temp_sett_id: 0)
  result.each do |player|
    if Time.now - 86_400 + 3600 <= Time.str_to_time(player['when_sett_joined']) then next end # 23 hours

    mysql_update('accounts', player['id'], settlement_id: player['temp_sett_id'])
    mysql_update('accounts', player['id'], temp_sett_id: 0)
    Message.insert('$ACTOR, having made it through the day, are now entitled to the benefits of settlement membership.',
                   speaker: player['id'])
  end
  'Settlement membership updated!'
end

def tick_damage_buildings
  puts "<li>Applying Storm Damage</li><ul>"
  regions = lookup_table(:region).values
  regions.each do |region|
    next if rand > 0.1

    puts "<li>#{region[:name]}</li>"
    tiles = mysql_select('grid', { region_id: region[:id] }, building_id: 0)
    tiles.each do |tile|
      dmg = rand(-5..9)
      next if dmg.negative?

      building = Building.new(tile['x'], tile['y'])
      next if building.special == :settlement
      next if building.special == :ruins # prevents storm damage

      # 17 = walls-reduce dmg odds/amt
      if building.id == 17
        dmg -= 3
        next if dmg <= 0
      end

      deal_damage(dmg, building)
      msg = "A storm blew across #{region[:name]}, doing #{dmg} damage to #{building.a}"
      mysql_insert('messages',
                   x: building.x,
                   y: building.y,
                   z: 0,
                   type: 'persistent',
                   message: msg)
    end
  end
  puts "</ul>"
end

def tick_grow_fields
  return 'Crops only grow in Summer' if season != :Summer

  tiles = mysql_select('grid', terrain: 91)
  tiles.each do |tile|
    growth = (tile['hp'].to_i * 3.5).to_i + 3
    mysql_bounded_update('grid', 'building_hp',
                         { x: tile['x'], y: tile['y'] }, +growth, 200)
  end
  tiles = mysql_select('grid', terrain: 92)
  tiles.each do |tile|
    growth = (tile['hp'].to_i * 3.5).to_i + 3
    mysql_bounded_update('grid', 'building_hp',
                         { x: tile['x'], y: tile['y'] }, +growth, 200)
  end
  'Fields grown!'
end

def tick_hunger
  query = 'SELECT * FROM `users` WHERE ' \
          "`active` = '1' AND " \
          "(`ap` <> '#{Max_AP}' OR " \
          '`lastaction` > (NOW() - INTERVAL 24 HOUR))'
  puts query
  players = db.query(query)
  players.each do |player|
    player = User.new(row: player)
    puts player.name
    if player.hunger.positive?
      player.update(hunger: (player.hunger - 1))
      next
    end

    # if user has noobcake, and is < level 2, auto eat
    if player.has_item?(23) # noobcake
      if player.skills.count < 2
        player.change_inv(23, -1)
        Message.insert("Feeling hungry, $ACTOR ate #{a_an('noobcake')}",
                       speaker: player)
        puts 'Om nom nom noobarific'
        next
      end
    end

    # if user has food, auto eat
    foods = lookup_all_where(:item, :use, :food)
    eaten = false
    foods.each do |food|
      next unless user_has_item?(player['id'], food[:id])

      mysql_change_inv(player['id'], food[:id], -1)
      Message.insert("Feeling hungry, $ACTOR ate #{a_an(food[:name])}",
                     speaker: player)
      eaten = true
      puts 'Om nom nom'
      break
    end
    next if eaten

    puts '*rumble*'
    hp_dmg = mysql_bounded_update('users', 'hp', player['id'], -3, 0)
    maxhp_dmg = mysql_bounded_update('users', 'maxhp', player['id'], -2, 25)
    if hp_dmg != 0
      Message.insert("$ACTOR, weakened by lack of food, lost <b>#{-hp_dmg} hp</b>",
                     speaker: player['id'])
      if player['hp'].to_i + hp_dmg <= 0 # dazed from hunger
        temp = mysql_select('accounts', id: player['id']).first
        if temp['temp_sett_id'].to_i != 0
          mysql_update('accounts', player['id'], temp_sett_id: 0)
          Message.insert('$ACTOR, dazed by hunger, have lost your pending settlement residency.',
                         speaker: player['id'])
        end
      end
    end
    next if maxhp_dmg.zero?

    Message.insert("$ACTOR, weakened by lack of food, lost <b>#{-maxhp_dmg} max hp</b>",
                   speaker: player['id'])
  end

  'Hungry guys!'
end

def tick_inactive
  query = 'UPDATE `users` SET `active` = 0 WHERE lastaction < (NOW() - INTERVAL 5 DAY)'
  db.query(query)
  'Inactive players!'
end

def tick_move_animals
  animals = mysql_select_all('animals')
  animals.each { |animal| move_animal(animal) }
  'Animals moved!'
end

def tick_restore_ap
  users = mysql_select('users', active: 1)
  users.each do |user|
    mysql_change_ap(user['id'], ap_recovery(user['id']))
  end
  'AP restored!'
end

def tick_restore_ip
  query = "UPDATE `ips` SET `hits` = '0'"
  db.query(query)
  'IP limits reset!'
end

def tick_restore_search
  tiles = mysql_select_all('grid')
  tiles.each do |tile|
    restore_odds = lookup_table_row(:terrain, tile['terrain'], :restore_odds)
    restore_odds = 10 if restore_odds.nil?
    next unless rand(100) < restore_odds

    case tile['terrain']
    when '8' # 8 -> 'dirt track'
      mysql_update('grid', { x: tile['x'], y: tile['y'] },
                   hp: 1, terrain: 1)
    else
      mysql_bounded_update('grid', 'hp',
                           { x: tile['x'], y: tile['y'] }, +1, 4)
    end
  end
  'Search rates restored!'
end

def tick_delete_rotten_food
  # delete rotten food that is on the ground but not in a built stockpile
  stockpiles = mysql_select_all('stockpiles')
  stockpiles.each do |stock|
    next unless stock['item_id'] == '33'

    onground = true
    builtpiles = mysql_select('grid', building_id: 3)
    builtpiles.each do |built|
      onground = false if (stock['x'] == built['x']) && (stock['y'] == built['y'])
    end
    mysql_delete('stockpiles', x: stock['x'], y: stock['y'], item_id: '33') if onground == true
  end
  'And so the rotten food on the ground became dirt.'
end

def tick_rot_food
  invs = mysql_select_all('inventories')
  invs.each do |inv|
    next if lookup_table_row(:item, inv['item_id'], :use) != :food

    rot_amount = Math.binomial(inv['amount'].to_i, Food_Rot_Chance)
    next if rot_amount.zero?

    puts rot_amount
    mysql_change_inv(inv['user_id'], inv['item_id'], -rot_amount)
    mysql_change_inv(inv['user_id'], :rotten_food, +rot_amount)
  end

  stockpiles = mysql_select_all('stockpiles')
  stockpiles.each do |stock|
    next if lookup_table_row(:item, stock['item_id'], :use) != :food

    rot_amount = Math.binomial(stock['amount'].to_i, Food_Rot_Chance)
    next if rot_amount.zero?

    puts rot_amount
    mysql_change_stockpile(stock['x'], stock['y'], stock['item_id'], -rot_amount)
    mysql_change_stockpile(stock['x'], stock['y'], :rotten_food, +rot_amount)
  end
  "I wouldn't eat that..."
end

def tick_spawn_animals
  puts "<li>Spawing Animals</li>"
  puts "<ul>"
  regions = lookup_table(:region)
  regions.each do |name, region|
    puts "<li>#{name}"
    animals = region[:animals_per_100]
    animals = [] if animals.nil?
    puts animals
    animals.each do |animal, amt|
      animal_id = lookup_table_row(:animal, animal, :id)
      animal_hp = lookup_table_row(:animal, animal, :max_hp)
      count = mysql_select('animals', region_id: region[:id], type_id: animal_id)
      habitats = habitats(animal)
      habitat_tiles = mysql_select('grid',
                                   region_id: region[:id], terrain: habitats)
      # changed 100 to 300 to reduce spawn rate
      spawn_no = ((habitat_tiles.count / 300.0) * amt * (rand + 0.5))
      freq = spawn_no / (habitat_tiles.count + 1) # to prevent dividing by zero
      max_allowed = ((habitat_tiles.count / 300.0) * amt) * 10 # (factor of DOOM!)
      # If > total animals of that type allowed for that region then skip spawning that type
      next unless max_allowed > count.count

      habitat_tiles.each do |tile|
        if rand < freq
          mysql_insert('animals', x: tile['x'], y: tile['y'],
                                  type_id: animal_id, hp: animal_hp, region_id: region[:id])
        end
      end
    end
  end
  puts "</ul>"
end

def tick_terrain_transitions
  tiles = mysql_select_all('grid')
  tiles.each do |tile|
    new_terrain = lookup_table_row(:terrain, tile['terrain'], :transition)
    next if new_terrain.nil?

    transition_odds = lookup_table_row(:terrain, tile['terrain'], :transition_odds)
    odds = if transition_odds.is_a?(Integer)
             transition_odds
           else
             transition_odds[season]
           end
    odds = transition_odds[:default] if odds.nil?
    next unless rand(100) < odds || odds == 100

    terrain_id = lookup_table_row(:terrain, new_terrain, :id)
    mysql_update('grid', { x: tile['x'], y: tile['y'] },
                 terrain: terrain_id)
  end
  'Forests regrown!'
end

def tick_delete_empty_data
  # Kill empty data to save space. Things like having 0 of an item are useless to keep around.
  db.query('delete from `inventories` where `amount` = 0')
  db.query('delete from `stockpiles` where `amount` = 0')
  'Empty/unneeded DB data dumped!'
end
