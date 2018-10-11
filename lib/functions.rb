load "data.rb"

class Class
  def data_fields(*fields)
    fields.each do |field|
      class_eval %Q[
        def #{field}
	        data[:#{field}]
	      end
      ]
    end
  end

  def mysql_fields(method = "mysql", *fields)
    fields.each do |field|
      class_eval %Q[
        def #{field}
	        #{method}['#{field}']
	      end
      ]
    end
  end

  def mysql_int_fields(method = "mysql", *fields)
    fields.each do |field|
      class_eval %Q[
        def #{field}
	        #{method}['#{field}'].to_i
	      end
      ]
    end
  end

  def mysql_float_fields(method = "mysql", *fields)
    fields.each do |field|
      class_eval %Q[
        def #{field}
	        #{method}['#{field}'].to_f
	      end
      ]
    end
  end
end

module Math
  def Math.binomial(trials, probability)
    successes = 0
    trials.times do
      if rand < probability then successes += 1 end
    end
    successes
  end
end

class Integer
  def to_1
    self == 0 ? 0 : (self < 0) ? -1 : 1
  end
end

class NilClass
  def each
    nil
  end

  def exists?
    false
  end

  def include?(x)
    false
  end

  def mysql_id
    nil
  end

  def name
    nil
  end

  def link
    nil
  end
end

class CGI
  def str_params
    $cgi.params
  end
end

class Float
  def to_t
    secs = self.to_i.abs
    if secs < 60
      return "#{secs} seconds"
    elsif secs < 3600
      mins = secs / 60
      return "#{mins} minutes"
    elsif secs < 3600 * 24
      hours = secs / 3600
      return "#{hours} hours"
    else
      days = secs / (3600 * 24)
      return "#{days} days"
    end
  end
end

class Time
  def self.str_to_time(str)
    Time.parse(str.to_s).localtime
  end

  def ago
    ((self - 0) - Time.now).to_t + " ago"
  end
end

class Animal
  @@mysql_table = "animals"

  data_fields "attack_odds", "attack_dmg", "habitats", "hit_msg", "loot",
    "max_hp", "when_attacked", "loot_bonus"

  mysql_int_fields "mysql", "x", "y", "z", "hp"

  attr_reader :mysql_id

  def data
    if @data == nil then @data = db_row(:animal, mysql["type_id"]) end
    @data
  end

  def exists?
    mysql != nil
  end

  def initialize(id)
    @mysql_id = id.to_i
  end

  def mysql
    @mysql ||= mysql_row("animals", @mysql_id)
  end

  def mysql_table
    @@mysql_table
  end

  def name
    "the " + data[:name]
  end

  def name_only
    data[:name]
  end
end

class Building
  @@mysql_table = "grid"

  data_fields "floors", "max_hp", "ap_recovery", "build_ap",
              "build_xp", "build_skill", "materials", "build_msg", "actions",
              "special", "prereq", "tools", "unwritable", "name", "interior",
              "use_skill", "effect_bonus", "craft_ap_bonus", "accuracy_bonus",
              "id"

  attr_reader :x, :y, :mysql_id

  def a
    a_an(data[:name])
  end

  def hp
    mysql["building_hp"].to_i
  end

  def description(z = 0)
    return "" unless self.exists?

    dmg = case (hp.to_f / max_hp)
          when (0...0.33)
            if mysql["building_id"] == "5" then "dying "             else "ruined " end
          when (0.33...0.67)
            if mysql["building_id"] == "5" then ""             else "damaged " end
          when (0.67...1)
            if mysql["building_id"] == "5" then "roaring "             else "dilapidated " end
          else
            if mysql["building_id"] == "5" then "raging "             else "" end
          end

    if z == 0
      desc = "There is #{a_an(dmg + data[:name])} here"
    else
      desc = self.interior
      desc = "You are inside #{a_an(dmg + data[:name])}" if desc == nil
    end

    if self.item_storage?
      desc += ', containing: <span class="small">'
      contents, _ = html_inventory(x, y, " ", :commas, :inline)
      desc += contents + "</span>"
    end
    if contents == "\n" then desc += "nothing" end
    desc += "."

    writing = writing(z)
    if writing
      if z == 0
        desc += " Written on #{name} are the words " +
                "<i>\"#{writing}\"</i>"
      else
        desc += " Written on the wall are the words " +
                "<i>\"#{writing}\"</i>"
      end
    end
    desc
  end

  def data
    if @data == nil
      @data = db_row(:building, mysql["building_id"])
    end
    @data
  end

  def exists?
    mysql["building_id"] != "0"
  end

  def item_storage?
    actions != nil && actions.include?(:take)
  end

  def improvements
    if self.exists?
      return [self.repair] if hp < max_hp && mysql["building_id"] != "5" # 5 = campfire
      key = id_to_key(:building, mysql["building_id"])
    else
      key = nil
    end

    all_where(:building, :prereq, key)
  end

  def initialize(x, y)
    @x, @y = x.to_i, y.to_i
    @mysql_id = {"x" => x, "y" => y}
  end

  def mysql
    @mysql ||= mysql_tile(@x, @y)
  end

  def mysql_table
    @@mysql_table
  end

  def name
    "the " + data[:name]
  end

  def prereq_id
    if prereq != nil then db_field(:building, prereq, :id)     else 0 end
  end

  def repair
    repair = data.clone
    multiplier =
      case (hp.to_f / max_hp)
      when (0...0.33) then 0.66
      when (0.33...0.67) then 0.33
      when (0.67..1) then 0
      else 0
      end
    repair[:repair] = true
    repair[:build_ap] = (build_ap * (multiplier + 0.33)).to_i
    repair[:build_xp] = (build_xp * multiplier).to_i
    repair[:materials] = {}
    data[:materials].each do
      |item, amt|
      repair[:materials][item] = (amt.to_f * multiplier).to_i
    end
    repair
  end

  def tile
    Tile.new(x, y)
  end

  def writing(z)
    if special == :settlement
      settlement = tile.settlement
      return "#{settlement.name}, population #{settlement.population}. " +
               "#{settlement.motto}"
    end
    writing = mysql_row("writings", {"x" => x, "y" => y, "z" => z})
    return nil if writing == nil
    return nil if writing["message"] == ""
    writing["message"]
  end
end

class Settlement
  mysql_int_fields "mysql", "x", "y", "leader_id", "allow_new_users"

  mysql_fields "mysql", "name", "motto", "title", "type",
    "founded", "website"

  attr_reader :mysql_id

  def ==(settlement)
    settlement.class == Settlement && settlement.mysql_id == mysql_id
  end

  def description
    if mysql["description"] != "" then mysql["description"]     else "A #{type} located in #{region_name}." end
  end

  def exists?
    mysql != nil
  end

  def image
    if mysql["image"] != "" then http(mysql["image"])     else "images/p_huts_small.jpg" end
  end

  def pending_ids
    query = "SELECT `accounts`.`id` " +
            "FROM `users` , `accounts` " +
            "WHERE `users`.`id` = `accounts`.`id` " +
            "AND `accounts`.`temp_sett_id` = '#{mysql_id}' " +
            "AND `users`.`active` = '1'"
    result = $mysql.query(query)
    pendings = []
    result.each { |row| pendings << row["id"] }
    pendings
  end

  def pendings
    pending_ids.map { |id| User.new(id) }
  end

  def pending_links
    pendings.map { |user| user.link }
  end

  #  def pending_names
  #    pendings.map {|user| user.name}
  #  end

  def inhabitant_ids
    query = "SELECT `accounts`.`id` " +
            "FROM `users` , `accounts` " +
            "WHERE `users`.`id` = `accounts`.`id` " +
            "AND `accounts`.`settlement_id` = '#{mysql_id}' " +
            "AND `users`.`active` = '1' ORDER BY `accounts`.`when_sett_joined`,`accounts`.`id` ASC"
    result = $mysql.query(query)
    inhabitants = []
    result.each { |row| inhabitants << row["id"] }
    inhabitants
  end

  def inhabitants
    @inhabitants ||= inhabitant_ids.map { |id| User.new(id) }
  end

  def inhabitant_links
    inhabitants.map(&:link)
  end

  def inhabitant_names
    inhabitants.map(&:name)
  end

  def initialize(id)
    @mysql_id = id.to_i
  end

  def leader
    @leader ||= User.new(leader_id)
  end

  def leader_link
    @leader_link ||= leader ? leader.link : "None"
  end

  def leader_name
    @leader_name ||= leader ? leader.name : "None"
  end

  def link
    if exists?
      desc = description
      if desc.length > 140
        desc = description.slice(0, 140) + "..."
      end
      desc.gsub!('"', '\'') # double - single quotes

      relation =
        if $user != nil then $user.relation(self)         else "neutral" end
      "<a href=\"settlement.cgi?id=#{mysql_id}\" " +
      "class=\"#{relation}\" " +
      "title=\"#{desc}\" " +
      ">#{name}</a>"
    else
      "<i>None</i>"
    end
  end

  def mysql
    @mysql ||= mysql_row("settlements", @mysql_id)
  end

  def population
    inhabitant_ids.nitems
  end

  def region_id
    tile = Tile.new(x, y)
    tile.region_id
  end

  def region_name
    tile = Tile.new(x, y)
    tile.region_name
  end
end

class Tile
  @@mysql_table = "grid"

  data_fields "actions"

  mysql_int_fields "mysql", "terrain", "building_id", "region_id", "hp", "building_hp"

  attr_reader :x, :y, :mysql_id

  def terrain
    if mysql
      if db_row(:terrain, mysql["terrain"]) then mysql["terrain"].to_i       else 3 end
    else
      3
    end
  end

  def ==(tile)
    self.x == tile.x && self.y == tile.y
  end

  def building
    Building.new(x, y)
  end

  def data
    if @data == nil then @data = db_row(:terrain, mysql["terrain"]) end
    if @data == nil then @data = db_row(:terrain, :wilderness) end
    @data
  end

  def description(z = 0)
    if z == 0
      desc = db_field(:terrain, terrain, season)
      desc = db_field(:terrain, terrain, :description) if desc == nil
      desc += " " + building.description(z)
      if terrain == 3
        dir = offset_to_dir(-(x.to_1), -(y.to_1), 0, :long)
        desc += " Civilisation is somewhere to the #{dir}."
      end
    else
      desc = building.description(z)
    end
    desc
  end

  def exists?
    !mysql_row("grid", {"x" => x, "y" => y}).nil?
  end

  def image
    image = db_field(:terrain, terrain, :image)
    if image.is_a?(Hash)
      if image[season] != nil
        image = image[season]
      else
        image = image[:default]
      end
    end
    if image == nil
      image = db_field(:terrain, :wilderness, :image)
    end
    image
  end

  def initialize(x, y)
    @x, @y = x.to_i, y.to_i
    @mysql_id = {"x" => x, "y" => y}
  end

  def mysql
    @mysql ||= mysql_tile(@x, @y)
  end

  def name
    "the #{data[:name]}"
  end

  def region_name
    db_field(:region, region_id, :name)
  end

  def settlement_id
    if @settlement_id == nil
      @settlement_id = false
      @settlement = false
      settlement = mysql_row("settlements", {"x" => (x - 2..x + 2), "y" => (y - 2..y + 2)})
      if !settlement.nil?
        # there's a settlement in the area, but is it close enough?
        x_offset = settlement["x"].to_i - x
        y_offset = settlement["y"].to_i - y
        if (x_offset * x_offset) + (y_offset * y_offset) <= 5
          @settlement_id = settlement["id"].to_i
          @settlement = Settlement.new(@settlement_id)
        end
      end
    end
    @settlement_id
  end

  def settlement
    settlement_id ? @settlement : nil
  end
end

class User
  @@mysql_table = "users"

  @@mysql_table_2 = "accounts"

  mysql_fields "mysql", "name", "lastaction", "password"

  mysql_float_fields "mysql", "ap"

  mysql_int_fields "mysql", "x", "y", "z", "hp", "maxhp", "hunger",
    "wander_xp", "herbal_xp", "combat_xp", "craft_xp", "active", "is_admin"

  mysql_int_fields "mysql_2", "settlement_id", "temp_sett_id",
    "frags", "kills", "deaths", "revives", "vote"

  attr_reader :mysql_id, :mysql_table

  def initialize(id)
    @mysql_id = id.to_i
  end

  def ==(user)
    user.class == User && user.mysql_id == mysql_id
  end

  def description
    if mysql_2["description"] != "" then mysql_2["description"]     else "A rather non-descript individual." end
  end

  def donated?
    mysql["donated"] == "1"
  end

  def is_admin?
    mysql['is_admin'].to_i == 1
  end

  def exists?
    mysql != nil
  end

  def joined
    Time.str_to_time(mysql_2["joined"]).ago
  end

  def image
    if mysql_2["image"] != ""
      http(mysql_2["image"])
    else
      "images/cave_art.jpg"
    end
  end

  def lastrevive
    Time.str_to_time(mysql_2["lastrevive"]).ago
  end

  def level(type = :all)
    if type == :all
      skills = db_table(:skill).values
    else
      skills = all_where(:skill, :type, type)
    end
    level = 0
    skills.each { |skill| level += 1 if has_skill?(self, skill[:id]) }
    level
  end

  def link
    html_userlink(mysql_id, name)
  end

  def mysql
    @mysql ||= mysql_user(@mysql_id)
  end

  def mysql_2
    @mysql_2 ||= mysql_row("accounts", @mysql_id)
  end

  def mysql_table
    @@mysql_table
  end

  def relation(target)
    case target.class.name
    when "User"
      return :ally if self == target
      type = mysql_row("enemies", {"user_id" => mysql_id, "enemy_id" => target.mysql_id})
      if type == nil
        if self.settlement.exists? && self.settlement == target.settlement
          return :ally
        end
      else
        case type["enemy_type"]
        when "1" then return :ally
        when "2" then return :enemy
        when "3" then return :contact3
        when "4" then return :contact4
        when "5" then return :contact5
        when "6" then return :contact6
        when "7" then return :contact7
        when "8" then return :contact8
        else return :contact255
        end
      end
      :neutral
    when "Settlement"
      return :ally if self.settlement == target
      :neutral
    end
  end

  def settlement
    settlement_id == 0 ? nil : Settlement.new(settlement_id)
  end

  def supporters
    result = mysql_select("accounts",
                          {"settlement_id" => settlement_id, "vote" => mysql_id})
    # return 0 if result.count == 0
    supporters = []
    result.each { |row| supporters << User.new(row["id"]) }
    supporters.delete_if { |user| user.hp == 0 || user.active == 0 }
    supporters.nitems
  end

  def tile
    Tile.new(self.x, self.y)
  end

  def magic # to prevent clicking on fake pages making you buy skills you don't want, etc.
    "#{self.lastaction.to_i}:#{self.name}"
  end
end

def a_an(str)
  (str =~ /^[aeiou].*/) ? "an #{sr}" : "a #{str}"
end

def add_fuel(user_id, magic)
  return "Error. Try again." if magic != $user.magic

  player = mysql_user(user_id)
  tile = mysql_tile(player["x"], player["y"])

  unless db_field(:building, tile["building_id"], :actions).include?(:add_fuel)
    return "There's nothing to add fuel to here."
  end

  if tile["building_hp"].to_i >= 30
    return "The fire is very large and is too hot to approach."
  end

  unless user_has_item?(user_id, :stick)
    return "You don't have any sticks to add to the fire."
  end

  mysql_change_inv(user_id, 1, -1)
  mysql_update("grid", {"x" => tile["x"], "y" => tile["y"]},
               {"building_hp" => (tile["building_hp"].to_i + 1)})
  #  mysql_put_message('action', "$ACTOR threw a stick on the fire", user_id) # waste of DB space
  mysql_give_xp(:wander, 1, user_id)
  mysql_change_ap(user_id, -1)
  "You throw a stick on the fire."
end

def all_where(table, column, value)
  db_table(table).values.find_all { |row| row[column] == value }
end

def altitude_mod(dest_terrain, start_terrain, user_id = nil, targ_sett = nil)
  return 0 if start_terrain == dest_terrain

  start_altitude = db_field(:terrain, start_terrain.to_i, :altitude)
  dest_altitude = db_field(:terrain, dest_terrain.to_i, :altitude)
  altitude = dest_altitude - start_altitude
  mod = case altitude
        when (-1..0) then 0
        when 1
          if user_id != nil && has_skill?(user_id, 17) then 1 # 17=mountaineering
                      else 2 end
        else nil # can't climb more than two height differences
        end
  if mod != nil
    if dest_terrain.to_i == 44 # goto wall
      if start_terrain.to_i == 45 || start_terrain.to_i == 47 # from gate/guardhouse
        mod = mod + 4
      else mod = mod + 69       end # anything besides a gate/guardhouse/wall to a wall
    elsif dest_terrain.to_i == 47 # gatehouse
      if start_terrain.to_i == 44 || start_terrain.to_i == 45 # || start_terrain.to_i == 45 # wall /#or guardstand/ to gatehouse
      elsif targ_sett == nil || (targ_sett == User.new(user_id).settlement) then       else mod = mod + 50       end
    end
  end
  return mod
end

def ap_cost(dest_terrain, start_terrain = nil, user_id = nil, targ_sett = nil)
  if start_terrain != nil
    altitude_mod = altitude_mod(dest_terrain, start_terrain, user_id, targ_sett)
  else
    altitude_mod = 0
  end
  return nil if altitude_mod == nil

  ap_data = db_field(:terrain, dest_terrain.to_i, :ap)
  if ap_data.is_a?(Numeric)
    ap_data + altitude_mod
  elsif user_id == nil
    # ap cost depends on skill, but we have no user_id, so return default cost
    default = ap_data[:default]
    if default != nil
      default + altitude_mod
    else
      nil
    end
  else
    # find lowest ap cost that user has skill for
    ap_data.delete_if { |skill, ap_cost|
      skill != :default && !has_skill?(user_id, skill)
    }
    costs = ap_data.values
    if costs.empty? then nil     else costs.min + altitude_mod end
  end
end

def ap_recovery(user_id)
  user = User.new(user_id)
  return 1 if user.hp == 0
  tile = user.tile
  ap = AP_Recovery.to_f
  building_bonus = db_field(:building, tile.building_id, :ap_recovery)
  ap += building_bonus if building_bonus != nil && (user.z != 0 || db_field(:building, tile.building_id, :floors) == 0)

  tile_bonus = db_field(:terrain, tile.terrain, :ap_recovery)
  ap += tile_bonus if tile_bonus != nil

  if ap == ap.to_i then ap.to_i   else ap end
end

def attack(attacker, target, item_id, magic)
  return "Error. Try again." if magic != $user.magic


  unless user_has_item?(attacker, item_id) || item_id.to_i == 24 # 24 -> fist
    return "You don't have #{a_an(db_field(:item, item_id, :name))}"
  end
  if attacker.mysql == nil || target.mysql == nil
    return ""
  end
  if attacker == target
    return "You stop yourself before inflicting any self-injury. Realizing that this is a cry for help, you turn to your bretheren for their sympathetic counsel."
  end
  if target.hp == 0
    return "You attack #{target.name}, but they're already knocked out."
  end
  if attacker.hp == 0
    return "You can't attack while dazed."
  end
  unless same_location?(attacker, target)
    return "#{target.name.capitalize} isn't in the vicinity."
  end
  if target.kind_of?(Building) && target.special == :settlement
    can_attack, msg = can_attack_totem?(target)
    unless can_attack then return msg end
  end
  if target.kind_of?(Building) && target.special == :ruins
    return "You ready yourself to attack, but can't bring yourself to harm the ruins."
  end
  weapon = db_row(:item, item_id)
  return "You can't attack with that." if weapon[:use] != :weapon
  if target.kind_of?(Building) && weapon[:weapon_class] != :slash
    return "You need an axe to attack buildings."
  end

  mysql_change_ap(attacker, -1)

  accuracy = item_stat(item_id, :accuracy, attacker)
  dmg =
    if target.kind_of? Building then rand_to_i(1.333)     else item_stat(item_id, :effect, attacker) end

  if rand(100) > accuracy || accuracy == 0
    msg = db_field(:weapon_class, weapon[:weapon_class], :miss_msg) +
          weapon[:name] +
          ", but missed!"
    msg += " " + attack_response(target, attacker)

    return insert_names(msg, attacker.mysql_id,
                        target.name, attacker.mysql_id, :no_link)
  end

  kill = deal_damage(dmg, target)

  msg = db_field(:weapon_class, weapon[:weapon_class], :hit_msg) +
        weapon[:name]

  if kill
    mysql_give_xp(:warrior, (20 + dmg), attacker)
    case target.class.name
    when "User"
      mysql_change_stat(attacker, "kills", +1)
      mysql_change_stat(target, "deaths", +1)
      msg += ", knocking $TARGET out."
      msg += " " + transfer_frags(attacker, target)
      mysql_put_message("visible_all",
                        "$ACTOR dazed $TARGET with #{a_an(db_field(:item, item_id, :name))}.",
                        attacker, target)
    when "Animal"
      target.loot.each do
        |item, amt| mysql_change_inv(attacker, item, +amt)       end
      msg += ", killing it! From the carcass you collect " +
             "#{describe_items_list(target.loot, "long")}."
      if has_skill?(attacker, 7) # 7 ->butchering temporary fix for butchering
        target.loot_bonus.each do
          |item, amt| mysql_change_inv(attacker, item, +amt)
          msg += "<br><br>You also manage to collect #{describe_items_list(target.loot_bonus, "long")} extra with your butchering prowess."         end
        mysql_put_message("visible_all",
                          "$ACTOR killed #{a_an(target.name_only)} with #{a_an(db_field(:item, item_id, :name))}",
                          attacker, target)
      end
    when "Building"
      msg += ", destroying it!"
    end
  else
    xp = ((dmg + 1) / 2).ceil
    mysql_give_xp(:warrior, xp, attacker)
    msg += " for #{dmg} hp damage."
    msg += " " + attack_response(target, attacker)
  end

  case target.class.name
  when "User"
    mysql_put_message("action", msg, attacker.mysql_id, target.mysql_id)
  when "Animal"
    #      mysql_put_message('action', msg, attacker.mysql_id) # waste of DB space
  when "Building"
    mysql_put_message("persistent",
                      "$ACTOR attacked #{target.a}", attacker.mysql_id)
  end

  msg += " " + break_attempt(attacker, item_id)

  insert_names(msg, attacker.mysql_id, target.name,
               attacker.mysql_id, :no_link)
end

def attack_response(target, attacker)
  msg = ""
  case target.class.name
  when "Animal"
    response = random_select(target.when_attacked, 100)
    case response
    when :attack
      dmg = target.attack_dmg
      kill = deal_damage(dmg, attacker)
      if kill
        mysql_change_stat(attacker, "deaths", +1)
        msg = "#{target.name.capitalize} #{target.hit_msg}, " +
              "knocking $ACTOR out!"
      else
        msg = "#{target.name.capitalize} #{target.hit_msg}, " +
              "for #{dmg} hp damage."
      end
    when :flee
      if move_animal(target.mysql)
        msg = "#{target.name.capitalize} flees the area."
      end
    end
  when "User"
    msg = "$TARGET flinched."
  end
  msg
end

def break_attempt(user, items)
  msg = ""

  if items == nil then return "" end

  if items.is_a?(Array)
    items.each { |item| msg += " " + break_attempt(user, item) }
    return msg
  end

  item = db_row(:item, items)
  break_odds = item[:break_odds]
  break_odds = 0 if break_odds == nil

  if rand() * 100 < break_odds
    mysql_change_inv(user, item[:id], -1)
    msg += "Your cherished #{item[:name]} breaks! " +
           "You throw away the useless pieces in disgust."
  end
  return msg
end

def build(user, building_id, magic)
  return "Error. Try again." if magic != $user.magic
  building_id = building_id.to_i
  tile = user.tile
  return repair(user) if tile.building_id == building_id

  building = db_row(:building, building_id)

  can_build, msg = can_build?(user, building)
  unless can_build then return msg end

  update_hash = {}
  case building[:special]
  when :settlement
    can_settle, can_settle_msg = can_settle?(tile)
    if can_settle
      $header["Location"] = "settle.cgi"
      return "...should be automatically redirected to settle.cgi..."
    else
      return can_settle_msg
    end
  when :terrain
    terrain_id = db_field(:terrain, building[:terrain_type], :id)
    update_hash["terrain"] = terrain_id
    update_hash["hp"] = building[:build_hp]
  when :walls
    terrain_id = db_field(:terrain, building[:terrain_type], :id)
    update_hash["terrain"] = terrain_id
    update_hash["hp"] = building[:build_hp]
    update_hash["building_id"] = building_id
    update_hash["building_hp"] =
      if building[:build_hp] != nil
        building[:build_hp]
      else
        building[:max_hp]
      end
  when nil
    update_hash["building_id"] = building_id
    update_hash["building_hp"] =
      if building[:build_hp] != nil
        building[:build_hp]
      else
        building[:max_hp]
      end
  end

  mysql_update("grid", tile.mysql_id, update_hash)

  building[:materials].each do
    |item, amt|
    mysql_change_inv(user, item, -amt)
  end

  msg = building[:build_msg]
  msg += break_attempt(user, building[:tools])

  xp_type = building[:build_xp_type]
  xp_type = :craft if xp_type == nil
  xp_amt = building[:build_xp]
  mysql_give_xp(xp_type, xp_amt, user)

  mysql_change_ap(user, -building[:build_ap])

  mysql_put_message("persistent",
                    "$ACTOR built #{a_an(building[:name])}", user.mysql_id)
  msg
end

def build_list(user)
  buildings = user.tile.building.improvements
  buildings.delete_if do |building|
    building[:build_skill] != nil && !has_skill?(user, building[:build_skill])
  end
end

def buildings_in_radius(tile, radius_squared, building)
  if building.is_a?(Array)
    total = 0
    building.each { |b| total += buildings_in_radius(tile, radius_squared, b) }
    return total
  end

  center_x, center_y = tile.x, tile.y
  radius = Math.sqrt(radius_squared).to_i
  tiles = []
  (-radius..radius).each do |x|
    (-radius..radius).each do |y|
      # ensure location is in circle using pythag
      if ((x * x) + (y * y)) <= radius_squared
        tiles << Tile.new(center_x + x, center_y + y)
      end
    end
  end

  building_id = db_field(:building, building, :id)
  tiles = tiles.select {|tile| tile.building_id == building_id }

  tiles.size
end

def buy_skill(user_id, skill_id, magic)
  return "Error. Try again." if magic != $user.magic
  user = User.new(user_id)
  if user.level >= Max_Level
    return "You have reached the current maximum level; you must unlearn " +
             "some skills before you can learn any more."
  end
  unless can_buy_skill?(user_id, skill_id)
    return "You are not able to buy that skill; " +
             "either you already have it, or lack the required prerequisites."
  end
  skill = db_row(:skill, skill_id)
  xp_cost = skill_cost(user.level(skill[:type]))
  xp_field = xp_field(skill[:type])

  user = mysql_user(user_id)
  if user[xp_field].to_i < xp_cost
    "You do not have sufficient #{db_field(:skills_renamed, :name, skill[:type])} xp to buy that skill."
  else
    mysql_bounded_update("users", xp_field, user_id, -xp_cost, 0)
    mysql_insert("skills", {"user_id" => user_id, "skill_id" => skill_id})
    "You have learned the arts of #{db_field(:skill, skill_id, :name)}."
  end
end

def can_attack_totem?(totem)
  big_buildings = db_table(:building).clone
  big_buildings.delete_if do
    |name, building|
    building[:settlement_level] == nil && building[:floors] == 0
  end
  big_buildings = big_buildings.keys
  building_amt = buildings_in_radius(totem.tile, 5, big_buildings)
  if building_amt > 0
    return false, "There are still #{building_amt} large buildings in " +
                  "the vicinity. You must destroy all the buildings in the area " +
                  "before you can attack #{totem.name}."
  else
    return true
  end
end

def can_act?(user)
  user.ap >= 1 && ($ip_hits == nil || $ip_hits <= 3300)
end

def can_build?(user, building)
  tile = user.tile

  if user.hp == 0
    return false, "In your dazed state, you can't remember how to build."
  end

  if building.is_a?(Symbol)
    building = db_row(:building, building)
  end

  unless has_skill?(user, building[:build_skill])
    return false, "You don't have the required skills " +
                  "to build #{a_an(building[:name])}."
  end

  if building[:special] == :terrain
    if tile.terrain != 1 && tile.terrain != 4 && tile.terrain != 24
      return false, "You cannot build #{a_an(building[:name])} here."
    end
  elsif building[:size] == :large
    if db_field(:terrain, tile.terrain, :build_large?) != true
      return false, "You cannot build #{a_an(building[:name])} here."
    end
  elsif building[:size] == :small
    if db_field(:terrain, tile.terrain, :build_small?) != true
      return false, "You cannot build #{a_an(building[:name])} here."
    end
  else
    if db_field(:terrain, tile.terrain, :build_tiny?) != true
      return false, "You cannot build #{a_an(building[:name])} here."
    end
  end

  if (building[:prereq] != nil and
      tile.building_id != db_field(:building, building[:prereq], :id)) or
     (building[:prereq] == nil and building[:id] != 10 and # 10 = dirt track
      tile.building_id != 0)
    return false, "You cannot build #{a_an(building[:name])} here."
  end

  if building[:settlement_level] != nil && tile.settlement == nil
    return false, a_an(building[:name]).capitalize +
                  " can only be built in an established settlement."
  end

  unless user_has_item?(user, building[:tools])
    return false, "You need " +
                  describe_items_list(building[:tools], "long") +
                  " to build #{a_an(building[:name])}."
  end

  unless user_has_item?(user, building[:materials])
    return false, "You need " +
                  describe_items_list(building[:materials], "long") +
                  " to build #{a_an(building[:name])}."
  end

  return true
end

def can_buy_skill?(user_id, skill_id)
  if has_skill?(user_id, skill_id) then return false end
  prereq = db_field(:skill, skill_id, :prereq)
  if prereq == nil || has_skill?(user_id, prereq) then true   else false end
end

def can_sell_skill?(user_id, skill_id)
  unless has_skill?(user_id, skill_id) then return false end
  skill = id_to_key(:skill, skill_id)
  post_reqs = all_where(:skill, :prereq, skill)
  post_reqs.each do |skill|
    return false if has_skill?(user_id, skill[:id])
  end
  true
end

def can_settle?(tile)
  totems = buildings_in_radius(tile, 400, :totem)
  if totems > 0
    return false, "There #{is_are(totems)} already #{totems} " +
                  "settlements near here; " +
                  "there must be no other totem poles within a 20-tile radius " +
                  "to build a new totem."
  end

  huts = buildings_in_radius(tile, 5, :hut)
  if huts < 3
    return false, "There #{is_are(totems)} only #{huts} huts near here; " +
                  "there must be at least three huts within your field of " +
                  "view (excluding corners) to build a new totem pole."
  end

  return true, "This looks like a fine spot to build a settlement. " +
               "Please choose a name for your new community."
end

def chat(user, text, magic)
  return "Error. Try again." if magic != $user.magic
  if text == "" then return "You can't think of anything to say." end
  if text.length > 255 then return "Message too long." end
  mysql_put_message("chat", CGI::escapeHTML(text), user)
  "You shout <i>\"#{CGI::escapeHTML(text)}\"</i> to the whole world."
end

def chop_tree(user_id, magic)
  return "Error. Try again." if magic != $user.magic
  user = mysql_user(user_id)
  tile = mysql_tile(user["x"], user["y"])
  tile_actions = db_field(:terrain, tile["terrain"], :actions)
  if tile_actions == nil || !tile_actions.include?(:chop_tree)
    return "There are no trees here."
  end

  if user["z"].to_i != 0
    return "You cannot chop down trees while inside."
  end

  unless user_has_item?(user_id, :hand_axe) ||
         user_has_item?(user_id, :stone_axe)
    return "You need an axe to chop down trees."
  end

  mysql_change_ap(user_id, -chop_tree_ap(user_id))
  mysql_give_xp(:wander, 2, user_id)
  mysql_change_inv(user_id, 15, +1) # 15 -> log
  mysql_put_message("persistent", "$ACTOR chopped down a tree", user_id)
  msg = "You chop down a tree, taking the heavy log."

  if rand < 0.12
    msg += " The tree cover in this area has been reduced."
    new_terrain =
      case tile["terrain"]
      when "21"
        if tile["hp"] == "0" then 82         else 24 end
      when "22" then 21
      when "23" then 22
      when "6" then 2
      when "2" then 7
      when "7"
        if tile["hp"] == "0" then 81         else 4 end
      end
    mysql_update("grid", {"x" => tile["x"], "y" => tile["y"]},
                 {"terrain" => new_terrain})
  end
  msg
end

def chop_tree_ap(user_id)
  if has_skill?(user_id, 15) # 15 -> lumberjack
    4
  else
    8
  end
end

def craft(user, item_id, magic)
  return "Error. Try again." if magic != $user.magic
  if user.hp == 0
    return "In your dazed state, you can't remember how to craft."
  end

  product = db_row(:item, item_id)
  if product[:craftable] != true
    return "That item cannot be crafted."
  end
  craft_skill = product[:craft_skill]
  if craft_skill != nil && !has_skill?(user, craft_skill)
    return "You do not have the required skills to craft that."
  end

  if product[:craft_building] != nil
    building = user.tile.building_id
    if db_field(:building, product[:craft_building], :id) != building
      return "You must be in the vicinity of " +
               "#{a_an(db_field(:building, product[:craft_building], :name))} to " +
               "craft #{a_an(product[:name])}."
    end
  end

  unless user_has_item?(user, product[:tools])
    return "You need " +
             describe_items_list(product[:tools], "long") +
             " to build #{a_an(product[:name])}."
  end

  unless user_has_item?(user, product[:materials])
    return "You need " +
             describe_items_list(product[:materials], "long") +
             " to build #{a_an(product[:name])}."
  end

  product[:materials].each do
    |item, amt|
    mysql_change_inv(user, item, -amt)
  end

  xp_type = product[:craft_xp_type]
  xp_type = :craft if xp_type == nil
  xp_amt = product[:craft_xp]
  mysql_give_xp(xp_type, xp_amt, user)
  mysql_change_ap(user, -product[:craft_ap])

  craft_amount = product[:craft_amount]
  craft_amount = 1 if craft_amount == nil
  mysql_change_inv(user, item_id, +craft_amount)

  if product[:extra_products]
    product[:extra_products].each do |item, value|
      mysql_change_inv user, item, +value
    end
  end
  msg = "You craft #{describe_items(craft_amount, item_id, :long)}."
  msg += break_attempt(user, product[:tools])
end

def craft_list(user_id)
  items = all_where(:item, :craftable, true)
  items.delete_if do |item|
    item[:craft_skill] != nil && !has_skill?(user_id, item[:craft_skill])
  end
end

def db_table(table)
  $Data[table]
end

def db_row(table, row)
  if row.is_a?(Integer)
    row_where(table, :id, row)
  elsif row.is_a?(String)
    # if row is a string, assume it's of the form "5" and convert to int
    row_where(table, :id, row.to_i)
  else
    db_table(table)[row]
  end
end

def db_field(table, row, field)
  row = db_row(table, row)
  if row != nil then row[field]   else nil end
end

def deal_damage(dmg, target)
  if target.hp > dmg
    field = "hp"
    field = "building_hp" if target.class == Building
    mysql_update(target.mysql_table, target.mysql_id,
                 {field => (target.hp - dmg)})
    kill = false
  else
    case target.class.name
    when "User"
      mysql_update("users", target.mysql_id, {"hp" => 0})
      if target.temp_sett_id != 0
        mysql_update("accounts", target.mysql_id, {"temp_sett_id" => 0})
        mysql_put_message("action", "$ACTOR, dazed before the day ended, have lost your pending settlement residency.",
                          target, target)
      end
    when "Animal"
      mysql_delete("animals", target.mysql_id)
    when "Building"
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
  when 0 then ""
  when 1
    if length == :short then db_field(:animal, type, :name)     else a_an(db_field(:animal, type, :name)) end
  else
    if length == :short then amount.to_s + " " +
                             db_field(:animal, type, :plural)     else describe_number(amount) + " " + db_field(:animal, type, :plural)     end
  end
end

def describe_animals_on_tile(x, y)
  animals = mysql_select("animals", {"x" => x, "y" => y})
  num_animals = animals.count

  if animals.count == 0 then return "" end

  animals = values_freqs_hash(animals, "type_id")
  animal_descs = animals.map do
    |type, amt| describe_animals(amt, type, :long)   end
  "#{describe_list(animal_descs).capitalize} #{is_are(num_animals)} here."
end

def describe_craft(item_row)
  craft_amt = item_row[:craft_amount]
  name =
    if craft_amt != nil && craft_amt != 0
      describe_items(craft_amt, item_row[:id])
    else
      item_row[:name].capitalize
    end

  name = "Repair #{name}" if item_row[:repair]

  ap_cost = item_row[:craft_ap]
  ap_cost = item_row[:build_ap] if ap_cost == nil

  tools, materials = [], []
  if item_row[:tools] != nil
    tools = item_row[:tools].map do |tool|
      describe_items(1, tool, "long")
    end
  end
  if item_row[:materials] != nil
    materials = item_row[:materials].map{ |item, amt| describe_items(amt, item, :short, " x ") }
  end
  "#{name} (#{ap_cost}ap, #{(tools + materials).join(", ")})"
end

def describe_items(amount, item, length = :short, infix = " ")
  case amount.to_i
  when 0 then ""
  when 1
    if length == :short then "1#{infix}#{db_field(:item, item, :name)}"     else a_an(db_field(:item, item, :name)) end
  else
    if length == :short
      "#{amount.to_s}#{infix}#{db_field(:item, item, :plural)}"
    else
      "#{describe_number(amount)}#{infix}#{db_field(:item, item, :plural)}"
    end
  end
end

def describe_items_list(items, length = :short, infix = " ")
  if items.is_a?(Hash)
    item_descs = items.map { |item, amt| describe_items(amt, item, length, infix) }
  else
    item_descs = items.map{ |item| describe_items(1, item, length, infix) }
  end
  describe_list(item_descs)
end

def describe_list(coll)
  # correctly formats an english list
  # eg -> [1,2,3,4] -> "1, 2, 3 and 4"
  array = coll.find_all { |x| x != nil }.to_a
  case array.length
  when 0
    ""
  when 1
    array[0].to_s
  when 2
    array[0].to_s + " and " + array[1].to_s
  else
    array[0].to_s + ", " + describe_list(array.slice(1..array.length))
  end
end

def describe_location(user_id)
  user = User.new(user_id)
  desc = user.tile.description(user.z)
  desc += " " + describe_animals_on_tile(user.x, user.y) if user.z == 0
  desc += " " + describe_occupants(user.x, user.y, user.z, user_id)
end

def describe_message(msg, user_id = nil)
  desc =
    case msg["type"]
    when "talk"
      "#{you_or_him(user_id, msg["speaker_id"], "You")} said " +
      "<i>\"#{msg["message"]}\"</i>" +
      if msg["target_id"] != "0"
        " to #{you_or_him(user_id, msg["target_id"])}"
      else ""       end
    when "whisper"
      case msg["target_id"]
      when "0"
        if user_id.to_s == msg["speaker_id"]
          "<b>You</b> mumbled something under your breath"
        else
          html_userlink(msg["speaker_id"]) +
          "mumbled something under their breath"
        end
      when user_id.to_s
        "#{html_userlink(msg["speaker_id"])} whispered " +
          "<i>\"#{msg["message"]}\"</i> to <b>you</b>"
      else
        if user_id.to_s == msg["speaker_id"]
          "<b>You</b> whispered <i>\"#{msg["message"]}\"</i> " +
            "to #{html_userlink(msg["target_id"])}"
        else
          "#{html_userlink(msg["speaker_id"])} whispered something " +
            "to #{html_userlink(msg["target_id"])}"
        end
      end
    when "shout"
      you_or_him(user_id, msg["speaker_id"], "You") +
      " shouted <i>\"#{msg["message"]}\"</i>" +
      if msg["target_id"] != "0"
        " to #{you_or_him(user_id, msg["target_id"])}"
      else ""       end
    when "game"
      msg["message"]
    when "distant"
      "Someone nearby shouted <i>\"#{msg["message"]}\"</i>"
    when "persistent"
      insert_names(msg["message"], msg["speaker_id"].to_i,
                   msg["target_id"].to_i, user_id)
    when "action"
      insert_names(msg["message"], msg["speaker_id"].to_i,
                   msg["target_id"].to_i, user_id)
    when "slash_me"
      insert_names(msg["message"], msg["speaker_id"].to_i,
                   msg["target_id"].to_i, user_id)
    when "visible_all"
      insert_names(msg["message"], msg["speaker_id"].to_i,
                   msg["target_id"].to_i, user_id)
    when "chat"
      html_userlink(msg["speaker_id"]) + ": " + msg["message"]
    else return ""
    end
  desc + "<span class=\"time\"> " +
    "#{Time.str_to_time(msg["time"]).ago}.</span>"
end

def describe_number(n)
  case n.to_i
  when 0 then "no"
  when 1 then "one"
  when 2 then "two"
  when 3 then "three"
  when 4 then "four"
  when 5 then "five"
  when 6 then "six"
  when 7 then "seven"
  when 8 then "eight"
  when 9 then "nine"
  when 10 then "ten"
  when 11 then "eleven"
  when 12 then "twelve"
  when 13 then "thirteen"
  when 14 then "fourteen"
  when 15 then "fifteen"
  when 16 then "sixteen"
  when 17 then "seventeen"
  when 18 then "eighteen"
  when 19 then "nineteen"
  when 20 then "twenty"
  when (21..29) then "twenty-" + describe_number(n - 20)
  when 30 then "thirty"
  when (31..39) then "thirty-" + describe_number(n - 30)
  when 40 then "forty"
  when (41..49) then "forty-" + describe_number(n - 40)
  else "loads of"
  end
end

def describe_occupants(x, y, z, omit = 0)
  occupants = mysql_select("users",
                           {"x" => x, "y" => y, "z" => z, "active" => 1}, {"id" => omit})
  if occupants.count == 0 then return "" end

  show_hp = true if has_skill?(omit, :triage)
  occupant_links = []
  occupants.each do |occupant|
    occupant_links << html_userlink(occupant["id"], occupant["name"], :details, show_hp)
  end
  if occupants.count == 1 then desc = "Standing here is "   else desc = "Standing here are " end
  desc += describe_list(occupant_links) + "."
end

def describe_weapon(item, user_id)
  # OOP delete!
  user = User.new(user_id)
  accuracy = item_stat(item[:id], :accuracy, user)
  dmg = item_stat(item[:id], :effect, user)
  desc = "#{item[:name].capitalize} (#{accuracy}%, #{dmg} dmg)"
  desc
end

def destroy_building(building)
  mysql_insert("messages", {"x" => building.x, "y" => building.y, "z" => 0,
                            "type" => "persistent", "message" => "#{building.a.capitalize} was destroyed!"})
  mysql_delete("writings", {"x" => building.x, "y" => building.y})
  mysql_update("users", {"x" => building.x, "y" => building.y}, {"z" => 0})
  mysql_update("grid", building.mysql_id,
               {"building_hp" => 0, "building_id" => 0})
  if building.special == :settlement
    destroy_settlement(building.tile.settlement)
  end
  if building.special == :walls
    mysql_update("grid", building.mysql_id,
                 {"building_hp" => 0, "building_id" => 0, "terrain" => 8, "hp" => 0})
  end
end

def destroy_settlement(settlement)
  mysql_insert("messages", {"x" => settlement.x, "y" => settlement.y, "z" => 0,
                            "type" => "persistent", "message" => "The settlement of #{settlement.name} was destroyed!"})
  mysql_update("accounts", {"settlement_id" => settlement.mysql_id}, {"settlement_id" => 0})
  mysql_update("accounts", {"temp_sett_id" => settlement.mysql_id}, {"temp_sett_id" => 0})
  mysql_delete("settlements", settlement.mysql_id)
end

def dig(user, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  return "You would rather not dig a hole in the floor." unless user.z == 0
  return "You cannot dig here." unless tile.actions.include?(:dig)
  unless user_has_item?(user, :digging_stick)
    return "You need a digging stick to dig here."
  end

  diggables = db_field(:terrain, tile.terrain, :dig)
  found_item = random_select(diggables, 100)
  if found_item == nil
    msg = "You dig a hole, but find nothing of use."
    mysql_change_ap(user, -2)
  else
    mysql_change_inv(user, found_item, 1)
    mysql_change_ap(user, -2)
    mysql_give_xp(:wander, 1, user)
    msg = "Digging a hole, you find #{db_field(:item, found_item, :desc)}."
  end

  msg += " " + break_attempt(user, :digging_stick)
end

def directions
  ["N", "NW", "W", "SW", "S", "SE", "E", "NE"]
end

def dir_to_offset(dir)
  case dir
  when "NW" then return -1, -1, 0
  when "Northwest" then return -1, -1, 0
  when "N" || "North" then return 0, -1, 0
  when "NE" || "Northeast" then return 1, -1, 0
  when "W" || "West" then return -1, 0, 0
  when "" then return 0, 0, 0
  when "E" || "East" then return 1, 0, 0
  when "SW" || "Southwest" then return -1, 1, 0
  when "S" || "South" then return 0, 1, 0
  when "SE" || "Southeast" then return 1, 1, 0
  when "Enter" then return 0, 0, 1
  when "In" then return 0, 0, 1
  when "Up" then return 0, 0, 1
  when "Down" then return 0, 0, -1
  when "Exit" then return 0, 0, -1
  when "Out" then return 0, 0, -1
  end
end

def drop(user, item_id, amount, magic)
  return "Error. Try again." if magic != $user.magic
  if item_id == nil then return "You drop nothing." end
  if amount.to_i < 1 || amount.to_i > 15 then return "That's an invalid quantity to drop." end
  amt_dropped = -mysql_change_inv(user, item_id, -amount.to_i)
  mysql_change_inv(user.tile, item_id, +amt_dropped)
  "You drop #{describe_items(amt_dropped, item_id, :long)}."
end

def encrypt(str)
  Digest::MD5.hexdigest(str)
end

def feed(feeder_id, target_id, item_id)
  target = mysql_user(target_id)
  item = db_row(:item, item_id)
  item_desc = a_an(item[:name])

  if target["hunger"].to_i >= Max_Hunger
    if feeder_id == target_id
      return "You're not feeling hungry at the moment."
    else
      return "You try offering #{item_desc} to #{target["name"]}, " +
               "but they're not hungry."
    end
  end
  mysql_change_inv(feeder_id, item_id, -1)
  mysql_bounded_update("users", "hunger", target_id, +1, Max_Hunger)
  mysql_bounded_update("users", "maxhp", target_id, +3, Max_HP)

  if feeder_id == target_id
    "You eat #{item_desc}."
  else
    mysql_put_message("action",
                      "$ACTOR fed $TARGET #{item_desc}", feeder_id, target_id)
    "You feed #{item_desc} to #{target["name"]}."
  end
end

def fill(user, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  return "You cannot fill a pot here." unless tile.actions.include?(:fill)
  unless user_has_item?(user, :pot)
    return "You don't have any container to fill with water."
  end

  mysql_change_inv(user, :water_pot, 1)
  mysql_change_inv(user, :pot, -1)
  mysql_change_ap(user, -1)
  "You fill a pot with water."
end

def get_validated_id
  if $cgi.include? "username"
    return false if $cgi["username"].length == 0
    user_id = mysql_user_id($cgi["username"])
    return false if user_id == nil
    return false unless validate_user(user_id, encrypt($cgi["password"]))
    $cookie = CGI::Cookie.new(
      "name" => "shintolin",
      "value" => [user_id.to_s, encrypt($cgi["password"])],
      "expires" => (Time.now + 1800),
    )
  else
    $cookie = $cgi.cookies["shintolin"]
    return false if $cookie == nil
    user_id = $cookie[0]
    return false unless validate_user(user_id, $cookie[1])
  end
  return user_id
end

def give(giver, receiver, amount, item_id, magic)
  return "Error. Try again." if magic != $user.magic

  unless receiver.exists? then return "" end

  if giver == nil || receiver == nil
    return "ERROR: Invalid user."
  end

  unless same_location?(giver, receiver)
    return "#{receiver.name} is not in the vicinity."
  end

  if receiver.kind_of?(Building) && !receiver.item_storage?
    return "You cannot leave items in #{receiver.name}."
  end

  if receiver.kind_of?(User) then if weight(receiver) >= Max_Weight
    return "#{receiver.name} already has as much as they can carry."
  end   end

  if item_id == nil then return "You give nothing to #{receiver.name}." end

  if amount.to_i < 1 || amount.to_i > 15 then return "That's an invalid quantity to give." end

  amt_given = -mysql_change_inv(giver, item_id, -amount.to_i)

  items_desc = describe_items(amt_given, item_id, :long)

  mysql_change_inv(receiver, item_id, amt_given)
  if receiver.is_a?(Building)
    mysql_put_message("persistent",
                      "$ACTOR dropped #{items_desc} in the stockpile", giver.mysql_id)
  else
    mysql_put_message("action",
                      "$ACTOR gave #{items_desc} to $TARGET", giver.mysql_id, receiver.mysql_id)
  end

  mysql_change_ap(giver, -1)
  "You give #{items_desc} to #{receiver.name}."
end

def habitats(animal)
  habitat_types = db_field(:animal, animal, :habitats)
  habitats = habitat_types.collect do |type|
    matches = all_where(:terrain, :class, type)
    matches.collect { |match| match[:id] } if matches
  end
  habitats.flatten!
end

def has_skill?(user, skill_id)

  # Delete this after OOP refactoring
  user_id =
    if user.kind_of?(Integer) || user.kind_of?(String)
      user
    else
      user.mysql_id
    end

  if skill_id == 0 || skill_id == nil || skill_id == :default
    return true
  end
  if skill_id.is_a?(Symbol)
    skill_id = db_field(:skill, skill_id, :id)
  end
  row = mysql_row("skills", {"user_id" => user_id, "skill_id" => skill_id})
  if row == nil then false   else true end
end

def harvest(user, magic)
  return "Error. Try again." if magic != $user.magic
  if season != :Autumn
    return "You must wait until Autumn before the crops can be harvested."
  end

  unless has_skill?(user, :agriculture)
    return "You have not yet discovered the secrets of agriculture."
  end

  tile = user.tile.mysql
  if tile["terrain"] != "91" # 91 = wheat field
    return "There is nothing to harvest here."
  end

  if (!user_has_item?(user, :hand_axe) &&
      !user_has_item?(user, :stone_axe) &&
      !user_has_item?(user, :stone_sickle))
    return "You need a sickle or an axe to harvest crops."
  end

  mysql_change_ap(user, -harvest_ap(user))
  mysql_give_xp(:herbal, 4, user)
  harvest_size = -mysql_bounded_update("grid", "building_hp",
                                       {"x" => user.x, "y" => user.y}, -10, 0)
  if mysql_tile(user.x, user.y)["building_hp"] == "0"
    mysql_update("grid", {"x" => user.x, "y" => user.y}, {"terrain" => 9})
  end
  mysql_change_inv(user, 21, +harvest_size) # 21 - wheat
  mysql_put_message("persistent",
                    "$ACTOR harvested #{harvest_size} measures of wheat from the field", user)
  "You harvest #{harvest_size} measures of wheat from the field."
end

def harvest_ap(user)
  if user_has_item?(user, :stone_sickle)
    8
  else
    16
  end
end

def heal(healer, target, item_id)
  item = db_row(:item, item_id)
  item_desc = a_an(item[:name])

  if target.hp >= target.maxhp
    if healer == target then return "You're already at full health."     else return "#{target.name} is already at full health." end
  end

  if target.hp == 0
    return you_or_her(healer.mysql_id, target.mysql_id, "You", false) +
             " are currently dazed and must be revived before healing items " +
             "have any effect."
  end

  mysql_change_inv(healer, item_id, -1)
  hp_healed = mysql_bounded_update("users", "hp",
                                   target.mysql_id, +item_stat(item_id, :effect, healer), target.maxhp)
  mysql_change_ap(healer, -1)
  xp = (hp_healed.to_f / 2) + 1
  mysql_give_xp(:herbal, xp, healer)

  if healer == target
    "You use #{item_desc} on yourself, healing #{hp_healed} hp."
  else
    mysql_put_message("action",
                      "$ACTOR used #{item_desc} on $TARGET, healing #{hp_healed} hp.",
                      healer, target)
    "You use #{item_desc} on #{target.name}, " +
    "healing #{hp_healed} hp of damage. " +
    "They now have #{target.hp + hp_healed} hp."
  end
end

def hours_mins_to_daytick
  # unfinished!
  unix_t = Time.now.to_i
  seconds_in_day = (3600 * 24)
  secs_past_midnight = unix_t - ((unix_t / seconds_in_day) * day_secs)
  hours_to_daytick = ((seconds_in_day - secs_past_midnight) / 3600)
end

def http(url)
  strip_http_re = /(http:\/\/)?(.*)/
  url = strip_http_re.match(url)[2]
  "http://" + url
end

def id_to_key(table, id)
  if id.kind_of? String then id = id.to_i end
  match = db_table(table).detect { |key, value| value[:id] == id }
  match[0]
end

def insert_breaks(str)
  str = str.gsub(/\r/, "<br>")
  str.gsub(/\n/, "")
end

def insert_names(str, actor_id, target_id, user_id = 0, link = true)
  if str.slice(0, 6) == "$ACTOR"
    # capitalise 'you' at start of msg
    str = str.sub(/\$ACTOR/, you_or_him(user_id, actor_id, "You", link))
  end
  # capitalise 'you' after '. '
  str = str.gsub(
    /(\. *)\$ACTOR/,
    '\1' + you_or_him(user_id, actor_id, "You", link)
  )
  str = str.gsub(/\$ACTOR/, you_or_him(user_id, actor_id, "you", link))

  # if target_id is an integer, replace $target with user of that id
  # otherwise, replace $target with target_id
  # (so we can pass, eg, "the deer" as a target)
  if target_id.kind_of?(Integer) && target_id != 0
    str = str.gsub(
      /(\. *)\$TARGET/,
      '\1' + you_or_him(user_id, target_id, "You", link)
    )
    str = str.gsub(/\$TARGET/, you_or_him(user_id, target_id, "you", link))
  else
    str = str.gsub(/(\. *)\$TARGET/, '\1' + target_id.to_s)
    str = str.gsub(/\$TARGET/, target_id.to_s)
  end
  str
end

def ip_hit(user_id = 0, hit = 10)
  return 0 if user_id != 0 && User.new(user_id).donated?
  ip = $cgi.remote_addr
  ip_row = mysql_row("ips", {"ip" => ip})
  if ip_row == nil
    mysql_insert("ips", {"ip" => ip, "hits" => hit, "user_id" => user_id})
    $ip_hits = hit
  else
    mysql_update("ips", {"ip" => ip}, {"hits" => (ip_row["hits"].to_i + hit)})
    $ip_hits = ip_row["hits"].to_i + hit
  end
  $ip_hits
end

def is_are(num)
  if num == 1 then "is"   else "are" end
end

def item_building_bonus(item_id, stat, user)
  building = user.tile.building
  return 1 unless building.exists?
  return 1 if building.use_skill == nil
  return 1 unless has_skill?(user, building.use_skill)
  item_type = db_field :item, item_id, :use
  return 1 if item_type == nil

  bonus_hash = case stat
               when :effect then building.effect_bonus
               when :craft_ap then building.craft_ap_bonus
               when :accuracy then building.accuracy_bonus
               end
  return 1 if bonus_hash == nil
  bonus = bonus_hash[item_type]
  return 1 if bonus == nil
  bonus
end

def item_stat(item_id, stat, user)
  multiplier = item_building_bonus item_id, stat, user
  data = db_field(:item, item_id, stat)
  return (data * multiplier).floor if data.is_a?(Integer)

  if data.is_a?(Hash)
    # data should be a hash of {skill => value}, find max/min value
    user_skills = data.delete_if { |skill, value| !has_skill?(user, skill) }
    if stat == :ap_cost
      data = user_skills.values.min
    else
      data = user_skills.values.max
    end
    return (data * multiplier).floor
  end

  if data == nil
    default =
      case stat
      when :ap_cost then 1
      when :effect then 0
      when :accuracy then 100
      else 0
      end
    return default
  end
end

def join(user, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  building = tile.building
  return "You must be at a totem pole to join a settlement." unless building.exists?
  unless building.actions.include? :join
    return "You must be at a totem pole to join a settlement."
  end
  if user.settlement_id == tile.settlement_id
    return "You are already a resident of #{tile.settlement.name}."
  end
  if user.temp_sett_id == tile.settlement_id
    return "You are already on your way to becoming a resident of #{tile.settlement.name}."
  end
  if user.hp <= 0
    return "You cannot join a settlement while you are dazed."
  end
  if user.settlement_id != 0 or user.temp_sett_id != 0
    return "You must relinquish your ties to other settlements before you can join."
  end
  if tile.settlement.population == 0
    mysql_update("accounts", user.mysql_id,
                 {"settlement_id" => tile.settlement_id})
    msg = "You pledge allegiance to #{tile.settlement.name}. As its only resident, you declare yourself its leader."
    mysql_update("accounts", user.mysql_id, {"vote" => user.mysql_id})
    mysql_update("settlements", tile.settlement_id, {"leader_id" => user.mysql_id})
  else
    mysql_update("accounts", user.mysql_id,
                 {"temp_sett_id" => tile.settlement_id})
    msg = "You pledge allegiance to #{tile.settlement.name}. You must survive the day to be entitled to its privileges."
  end
  mysql_update("accounts", user.mysql_id,
               {"when_sett_joined" => :Now})
  mysql_change_ap(user.mysql_id, -25)
  mysql_put_message("persistent", "$ACTOR made a pledge to join this settlement.", user)
  if user.settlement_id != 0
    msg += " You are no longer a resident of #{user.settlement.name}."
  end
  msg
end

def leave(user, magic)
  return "Error. Try again." if magic != $user.magic
  if user.settlement_id == 0 && user.temp_sett_id == 0
    return "You are not currently a member of any settlement."
  end
  if user.settlement_id != 0
    if user.mysql_id == user.settlement.leader_id # Non-residents don't get to be leader :P
      mysql_update("settlements", user.settlement_id,
                   {"leader_id" => 0})
    end
  end
  mysql_update("accounts", user.mysql_id,
               {"settlement_id" => 0})
  if user.temp_sett_id != 0
    mysql_update("accounts", user.mysql_id,
                 {"temp_sett_id" => 0})
    return "You give up your attempt to gain settlement residency."
  end
  "You are no longer a resident of #{user.settlement.name}."
end

def logout(user, magic)
  return "Error. Try again." if magic != $user.magic
  # delete cookies
  $cookie.expires = Time.now

  # undo ip hit cost
  ip_hit(user.mysql_id, -10)

  # redirect to homepage
  $header["Location"] = "./index.cgi"
end

def minutes_to_hour
  unix_t = Time.now.to_i
  seconds_past = unix_t - ((unix_t / 3600) * 3600)
  ((3600 - seconds_past) / 60) + 1
end

def month
  # Ruby calculates time in seconds by GMT. To synch up with cron, we must lie and say whatever time zone we're in is actually GMT, -then- calculate the seconds.
  gmt_time = Time.now.to_a
  local_time = Time.utc(gmt_time[5], gmt_time[4], gmt_time[3], gmt_time[2], gmt_time[1], gmt_time[0])

  day = local_time.to_i / (3600 * 24) % 3
  prefix =
    case day
    when 0 then "Early "
    when 1 then "Mid "
    when 2 then "Late "
    end
  prefix + season.to_s
end

def move(user_id, x, y, z, magic)
  # return "Error. Try again." if magic != $user.magic
  x, y, z = x.to_i, y.to_i, z.to_i
  if (not [-1, 0, 1].include? x) or
     (not [-1, 0, 1].include? y) or
     (not [-1, 0, 1].include? z)
    throw "bad number"
  end
  mover = mysql_user(user_id)
  current_tile = mysql_tile(mover["x"], mover["y"])
  user = User.new user_id
  if weight(user) > Max_Weight
    return "You are over-encumbered and cannot move."
  end

  if z == 0
    # move player in cardinal direction, if player is not in building
    # includes fix for 'stuck in stockpile bug'
    if (user.z != 0 &&
        user.tile.building.exists? &&
        user.tile.building.floors != 0)
      "You must leave the building before you can move " +
      offset_to_dir(x, y, z, :long) + "."
    else
      # get ap cost for target tile
      target_x = mover["x"].to_i + x
      target_y = mover["y"].to_i + y
      target_tile = mysql_tile(target_x, target_y)
      targ_sett = Tile.new(target_x, target_y).settlement
      ap_cost = ap_cost(target_tile["terrain"],
                        current_tile["terrain"], user_id, targ_sett)
      if ap_cost != nil
        mysql_change_ap(user_id, -ap_cost) unless user.is_admin?
        xp = db_field(:terrain, target_tile["terrain"], :xp)
        if xp != nil
          xp = rand_to_i(xp)
          mysql_give_xp(:wander, xp, user_id)
        end
        mysql_update("users", user_id, {"x" => target_x, "y" => target_y, "z" => 0})
        "You head #{offset_to_dir(x, y, z, :long)}."
      else
        "You cannot move there."
      end
    end
  else
    target_z = mover["z"].to_i + z
    if valid_location?(mover["x"], mover["y"], target_z)
      mysql_update("users", user_id, {"z" => target_z})
      mysql_change_ap(user_id, -1)
      case target_z
      when 0 then "You head outside."
      when 1 then "You head inside."
      else "You move to floor " + target_z.to_s
      end
    else
      "You cannot move there."
    end
  end
end

def move_animal(animal)
  tile = mysql_tile(animal["x"], animal["y"])
  animal_data = db_row(:animal, animal["type_id"])

  return false if animal_data[:immobile]

  habitats = habitats(animal["type_id"])
  8.times {
    dir = random_dir
    x, y = dir_to_offset(dir)
    dest_tile = mysql_tile(animal["x"].to_i + x, animal["y"].to_i + y)
    if habitats.include?(dest_tile["terrain"].to_i)
      mysql_update("animals", animal["id"],
                   {"x" => (animal["x"].to_i + x), "y" => (animal["y"].to_i + y)})
      return true
    end
  }
  return false
end

def msg_dazed(player)
  if player["hp"].to_i == 0
    "You are dazed. Until you are revived, " +
    "your actions are limited and you will regain AP more slowly."
  else
    ""
  end
end

def msg_tired(player)
  if player["ap"].to_f < 1
    "Totally exhausted, you collapse where you stand."
  elsif $ip_hits > 3300
    "<span class='ipwarning'>" +
    "You have exceeded your IP limit for the day (enough for three characters). " +
    "Please wait until tomorrow to play again.</span>"
  elsif $ip_hits > 3150 && $ip_hits < 3301
    "<br><span class='ipwarning'>" +
    "You are nearing your IP limit for the day. " +
    "You might want to finish up what you are doing " +
    "or get somewhere safe.</span>"
  else
    ""
  end
end

def msg_no_ap(user_id)
  player = mysql_user(user_id)
  msg = "You must wait for your AP to recover (about "
  hours = ((0 - player["ap"].to_f) / ap_recovery(user_id)).to_i
  msg += hours.to_s + " hours, " if hours != 0
  msg += minutes_to_hour.to_s + " minutes" +
         ") before you can act."
end

def msg_no_ip
  min = Time.now.min; if min < 10 then min = "0" + min.to_s end
  hour = Time.now.hour; if hour < 10 then hour = "0" + hour.to_s end
  "You have used up your IP hits for the day. IPs reset around " +
  "midnight server time. It is currently #{hour}:#{min}."
end

def ocarina(user, target, item_id)
  item = db_row(:item, item_id)
  item_desc = a_an(item[:name])
  mysql_change_ap(user, -0.2)
  if user == target
    mysql_put_message("visible_all",
                      "$ACTOR played a lively melody on the ocarina",
                      user)

    if rand < 0.3
      msg = "You play a lively melody on your ocarina. " +
            "A whirlwind appears and attempts to carry you off, " +
            "but you're too heavy."
    else
      msg = "You play a lively melody on your ocarina."
    end
  else
    mysql_put_message("visible_all",
                      "$ACTOR played a lively melody on the ocarina for $TARGET",
                      user, target)
    "You play a lively melody on your ocarina " +
    "for #{target.name}."
  end
end

def offset_to_dir(x_offset, y_offset, z_offset = 0, length = :short)
  case z_offset
  when 0
    case y_offset
    when -1
      case x_offset
      when -1 then if length == :short then "NW"         else "Northwest" end
      when 0 then if length == :short then "N"         else "North" end
      when 1 then if length == :short then "NE"         else "Northeast" end
      else nil
      end
    when 0
      case x_offset
      when -1 then if length == :short then "W"         else "West" end
      when 0 then nil
      when 1 then if length == :short then "E"         else "East" end
      else nil
      end
    when 1
      case x_offset
      when -1 then if length == :short then "SW"         else "Southwest" end
      when 0 then if length == :short then "S"         else "South" end
      when 1 then if length == :short then "SE"         else "Southeast" end
      else nil
      end
    else nil
    end
  when 1 then if length == :short then "In"     else "inside" end
  when -1 then if length == :short then "Out"     else "outside" end
  else nil
  end
end

def quarry(user, magic)
  return "Error. Try again." if magic != $user.magic
  return "You cannot quarry here." unless user.tile.actions.include?(:quarry)
  unless has_skill?(user, :quarrying)
    return "You do not have the required skills to quarry."
  end
  return "You need a pick to quarry here." unless user_has_item?(user, :bone_pick) ||
                                                  user_has_item?(user, :ivory_pick)
  mysql_change_ap(user, -4)
  if rand < 0.5
    msg = "Chipping away at the rock face, you manage to work free " +
          "a large boulder."
    mysql_change_inv(user, :boulder, 1)
    mysql_give_xp(:craft, 2.5, user)
  else
    msg = "You chip away at the rock face, but fail to remove anything."
  end
  if user_has_item?(user, :ivory_pick)
    msg += " " + break_attempt(user, :ivory_pick)
  else
    msg += " " + break_attempt(user, :bone_pick)
  end
end

def random_dir
  directions[rand(8)]
end

def random_select(hash, denom = 0)
  # when passed a hash of the form
  # {option1 => probability, option2 => probability, etc}
  # returns one of the options
  # if denom is set, chance of option1 being returned
  # equals probality1/denom
  # if not, chance of option1 being returned equals
  # probability1/sum of probabilities

  if denom == 0
    denom = sum_coll(hash.values)
  end
  rnd = rand() * denom
  selected = nil
  hash.each { |option, chance|
    # puts "Chance: " + chance.to_s + " Rnd: " + rnd.to_s
    if chance > rnd
      selected = option
      break
    else
      rnd = rnd - chance
    end
  }
  selected
end

def rand_to_i(x)
  # eg, if x is 1.4, returns 1 60% of the time and 2 40% of the time
  fraction = x - x.floor
  if rand < fraction then x.floor + 1   else x.floor end
end

def repair(user)
  building = user.tile.building.repair

  unless has_skill?(user, building[:build_skill])
    return "You don't have the required skills " +
             "to repair the #{building[:name]}."
  end

  unless user_has_item?(user, building[:tools])
    return "You need " +
             describe_items_list(building[:tools], "long") +
             " to repair the #{building[:name]}."
  end

  unless user_has_item?(user, building[:materials])
    return "You need " +
             describe_items_list(building[:materials], "long") +
             " to repair the #{building[:name]}."
  end

  unless user.tile.building_hp < building[:max_hp]
    return "The #{building[:name]} does not need any repairs."
  end

  if building[:name] == "campfire"
    return "Use the Add Fuel button instead."
  end

  mysql_update("grid", user.tile.mysql_id,
               {"building_hp" => building[:max_hp]})

  building[:materials].each do
    |item, amt|
    mysql_change_inv(user, item, -amt)
  end

  msg = "You repair the #{building[:name]}. "
  msg += break_attempt(user, building[:tools])

  xp_type = building[:build_xp_type]
  xp_type = :craft if xp_type == nil
  xp_amt = building[:build_xp]
  mysql_give_xp(xp_type, xp_amt, user)

  mysql_change_ap(user, -building[:build_ap])

  mysql_put_message("persistent",
                    "$ACTOR repaired #{a_an(building[:name])}", user.mysql_id)
  msg
end

def revive(healer_id, target_id, item_id)
  healer = User.new healer_id
  target = User.new target_id
  item = db_row(:item, item_id)
  item_desc = a_an(item[:name])
  if healer == target and healer.hp != 0
    return "You can't revive yourself. Especially when you're not dazed."
  end
  if healer == target
    return "You can't revive yourself. You'll have to find someone else to revive you."
  end
  if target.hp != 0
    return "You try using #{item_desc} on " +
             "#{target.name}, however it doesn't have any effect. " +
             "Try using it on someone who has been knocked out."
  end

  if healer.hp == 0
    return "You try using #{item_desc} on " +
             "#{target.name} with little success. " +
             "You can't revive others while you're dazed."
  end

  tile = Tile.new(healer.x, healer.y)
  if tile.settlement != healer.settlement && tile.settlement != nil
    return "You are not a member of " + tile.settlement.name + ", and cannot perform revives within its boundries."
  end

  if target.hunger == 0
    return "#{target.name} is starved. They need a little food before herbal remedies will do any good."
  end

  hp_healed = mysql_bounded_update("users", "hp",
                                   target.mysql_id, +item_stat(item_id, :effect, healer), target.maxhp)
  xp = (hp_healed.to_f / 2).ceil + 10
  mysql_update("users", target_id, {"hp" => hp_healed})
  mysql_change_ap(healer_id, -10)
  mysql_give_xp(:herbal, xp, healer)
  mysql_change_inv(healer_id, item_id, -1)
  mysql_change_stat(healer, "revives", +1)
  mysql_update("accounts", target_id, {"lastrevive" => :Today})
  mysql_put_message("action",
                    "$ACTOR used #{item_desc} on $TARGET, reviving them from their daze.",
                    healer_id, target_id)
  "You use #{item_desc} on #{target.name}, reviving them from their daze. " +
  "They now have #{hp_healed} hp."
end

def row_where(table, column, value)
  db_table(table).values.detect { |row| row[column] == value }
end

def same_location?(a, b)

  # this should be deleted after OOP refactoring!
  if a.kind_of?(Hash) && b.kind_of?(Hash)
    return a["x"] == b["x"] && a["y"] == b["y"] && a["z"] == b["z"]
  end

  unless a.exists? || !b.exists?
    puts "One of the arguments to same_location? refers to an invalid entity."
    return false
  end

  if a.kind_of?(Building) || b.kind_of?(Building)
    return a.x == b.x && a.y == b.y
  end

  return a.x == b.x && a.y == b.y && a.z == b.z
end

def say(speaker, message, volume, magic, target = nil)
  return "Error. Try again." if magic != $user.magic

  if volume != "Talk" && volume != "Shout" && volume != "Whisper"
    return "Error. Try again."
  end

  if message.length > 255 then return "Message too long." end

  # check for '/me'
  if message.slice(0, 3) == "/me"
    message = message.gsub(/\/me/, "$ACTOR")
    message = message.gsub(/\/you/, "$TARGET")
    volume = "slash_me"
  end
  volume.downcase!

  # if there's a target, check they're nearby
  if target.exists? && !same_location?(speaker, target)
    return "#{target.name} is not in the vicinity."
  end

  if message == "" then return "You can't think of anything to say." end

  message = CGI::escapeHTML(message)
  mysql_change_ap(speaker, -0.2)
  mysql_put_message(volume, message, speaker, target)

  # insert 8 distance messages if shouting
  if volume == "shout"
    mysql_change_ap(speaker, -2)
    dirs = ["NW", "N", "NE", "E", "SE", "S", "SW", "W"]
    dirs.each do |dir|
      x, y, z = dir_to_offset(dir)
      mysql_insert("messages",
                   {"speaker_id" => speaker.mysql_id, "message" => message, "type" => "distant",
                    "x" => (speaker.x + x), "y" => (speaker.y + y),
                    "z" => (speaker.z + z)})
    end
  end

  # work out display
  if volume == "slash_me"
    target_id =
      if target.exists? then target.mysql_id       else 0 end
    insert_names(message, speaker.mysql_id, target_id, speaker.mysql_id)
  else
    if volume == "talk" then volume = "say" end
    "You #{volume} <i>\"#{message}\"</i>" +
    if target.exists? then " to #{target.name}."     else "" end
  end
end

def season
  # Ruby calculates time in seconds by GMT. To synch up with cron, we must lie and say whatever time zone we're in is actually GMT, -then- calculate the seconds.
  gmt_time = Time.now.to_a
  local_time = Time.utc(gmt_time[5], gmt_time[4], gmt_time[3], gmt_time[2], gmt_time[1], gmt_time[0])

  three_day_block = local_time.to_i / (3600 * 24 * 3) % 4
  case three_day_block
  when 0 then :Winter
  when 1 then :Spring
  when 2 then :Summer
  when 3 then :Autumn
  end
end

def game_year
  gmt_time = Time.now.to_a
  game_time = Time.utc(gmt_time[5], gmt_time[4], gmt_time[3], 0, 0, 0)
  game_time = game_time - Time.utc(2009, 3, 28, 0, 0, 0)
  game_year = game_time.to_i / (12 * 60 * 60 * 24)
end

def search(user, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  mysql_change_ap(user, -1)

  search = db_field(:terrain, tile.terrain, :search)

  if user.z == 0 and tile.terrain == 99 #searching in ruins
    return "You look around the area, but find nothing of use."
  end
  if user.z != 0 and tile.terrain != 99
    return "You look around the building, but find nothing of use."
  end

  if search == nil
    return "There appears to be nothing to find here."
  end
  items = search.clone
  # modify search rates based on season
  items.collect {
    |item, odds|
    season_mod = db_field(:item, item, season)
    # puts season_mod
    if season_mod != nil then items[item] = odds * season_mod end
    # puts "Item: #{item} #{items[item]}%"
  }
  case tile.hp
  when 0
    items.clear
  when 1
    items.collect { |item, odds| items[item] = odds * 0.5 }
  when 2
    items.collect { |item, odds| items[item] = odds * 0.75 }
  end
  total_odds = sum_coll(items.values)

  tile_change = user.tile.mysql
  if !has_skill?(user, :foraging)
    hp_msg =
      case total_odds
      when 0
        if tile_change["terrain"] == "1"
          mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 8})
          "This area appears to have been picked clean."
        elsif tile_change["terrain"] == "4"
          mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 81})
          "This area appears to have been picked clean."
        elsif tile_change["terrain"] == "24"
          mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 82})
          "This area appears to have been picked clean."
        else
          "This area appears to have been picked clean."
        end
      else ""
      end
  else
    case total_odds
    when 0
      if tile_change["terrain"] == "1"
        mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 8})
        hp_msg = "This area appears to have been picked clean."
      elsif tile_change["terrain"] == "4"
        mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 81})
        hp_msg = "This area appears to have been picked clean."
      elsif tile_change["terrain"] == "24"
        mysql_update("grid", {"x" => tile_change["x"], "y" => tile_change["y"]}, {"terrain" => 82})
        hp_msg = "This area appears to have been picked clean."
      else
        hp_msg = "This area appears to have been picked clean."
      end
    when (0..10)
      hp_msg = "This area appears to have very limited resources,"
    when (10..20)
      hp_msg = "This area appears to have limited resources,"
    when (20..30)
      hp_msg = "This area appears to have moderate resources,"
    when (30..40)
      hp_msg = "This area appears to have abundant resources,"
    when (40..200)
      hp_msg = "This area appears to have very abundant resources,"
    else hp_msg = "You just hit the motherlode. This place is rich,"
    end
    case tile.hp
    when 0
    when 1
      hp_msg += " and is below average for this time of year."
    when 2
      hp_msg += " and is roughly average for this time of year."
    else
      hp_msg += " and is above average for this time of year."
    end
  end

  found_item = random_select(items, 100)
  if found_item == nil
    msg = search_hidden_items(user)
    msg = "Searching the area, you find nothing of use." if msg == nil
    return msg + " " + hp_msg
  end
  if found_item.is_a?(String)
    return found_item
  end

  if rand < Search_Dmg_Chance
    mysql_bounded_update("grid", "hp", tile.mysql_id, -1, 0)
  end
  mysql_change_inv(user, found_item, +1)
  mysql_give_xp(:wander, 1, user)
  "Searching the area, you find " +
    db_field(:item, found_item, :desc) + ". " + hp_msg
end

def search_hidden_items(user)
  tile = user.tile
  return nil if tile.building.exists? && tile.building.item_storage?
  item_rows = mysql_select("stockpiles", tile.mysql_id, {"amount" => 0})
  item_amts = {}
  item_rows.each do |row|
    item_amts[row["item_id"].to_i] = row["amount"].to_i
  end
  found_item = random_select(item_amts, 100)
  return nil if found_item == nil
  amount_found = -mysql_change_inv(tile, found_item, -10)
  mysql_change_inv(user, found_item, amount_found)
  "Searching the area, you find " +
    describe_items(amount_found, found_item, :long) +
    " which someone has abandoned."
end

def sell_skill(user_id, skill_id, magic)
  return "Error. Try again." if magic != $user.magic
  unless can_sell_skill?(user_id, skill_id)
    return "You cannot sell #{db_field(:skill, skill_id, :name)} " +
             "until you have sold all the skills that come after it."
  end

  mysql_delete("skills", {"user_id" => user_id, "skill_id" => skill_id})
  "A wise man once said <i>\"Everything new I learn pushes some old stuff out " +
  "of my brain\".</i>  You have forgetten the arts of " +
  "#{db_field(:skill, skill_id, :name)}."
end

def settle(user, settlement_name, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  can_settle, settle_msg = can_settle?(tile)
  unless can_settle
    return settle_msg
  end

  can_build, build_msg = can_build?(user, :totem)
  unless can_build
    return build_msg
  end

  if $cgi["text"].length < 2
    return "Your settlement name must be at least two characters."
  end
  if not $cgi["text"] =~ /^\s?[a-zA-Z0-9 .\-']*\s?$/
    return "Your settlement name must not contain invalid characters."
  end
  if $cgi["text"] != $cgi["text"].strip
    return "Your settlement name must not have spaces at the beginning or end."
  end
  if mysql_row("settlements", {"name" => settlement_name}) != nil
    return "There is already a settlement of that name."
  end

  mysql_change_inv(user, :log, -1)
  mysql_change_ap(user, -30)
  mysql_update("grid", tile.mysql_id, {"building_id" => 4, "building_hp" => 30}) # 4 -> totem pole
  mysql_insert("settlements",
               {"name" => settlement_name, "x" => tile.x, "y" => tile.y, "founded" => :Today, "leader_id" => user.mysql_id})
  mysql_update("accounts", user.mysql_id,
               {"settlement_id" => tile.settlement_id, "vote" => user.mysql_id, "when_sett_joined" => :Now})
  mysql_put_message("persistent",
                    "$ACTOR established the settlement of #{settlement_name}", user)

  "You have established the settlement of #{settlement_name}. " +
  "May it grow and prosper."
end

def skill_cost(level)
  (level + 2) * 30
end

def sow(user, item_id, magic)
  return "Error. Try again." if magic != $user.magic
  if season != :Spring
    return "Crops can only be planted in Spring."
  end

  unless has_skill?(user, :agriculture)
    return "You have not yet discovered the secrets of agriculture."
  end

  tile = user.tile.mysql
  if tile["terrain"] != "9" # 9 = empty field
    return "You cannot plant anything here."
  end

  item = db_row(:item, item_id)
  if item[:plantable] != true
    return "You cannot plant #{item[:plural]}."
  end

  if user_item_amount(user, item_id) < 10
    return "You must have at least ten #{item[:plural]} to plant a field."
  end

  # possibly decrease tile fertility
  if tile["hp"] > "3"
    mysql_bounded_update("grid", "hp", {"x" => tile["x"], "y" => tile["y"]}, -1, 0)
  else
    if rand(5) <= 1
      mysql_bounded_update("grid", "hp", {"x" => tile["x"], "y" => tile["y"]}, -1, 0)
      if tile["hp"] <= "1"
        mysql_update("grid", {"x" => tile["x"], "y" => tile["y"]}, {"terrain" => 8})
        return "This field has been overfarmed; " +
                 "no crops can be grown here until the land recovers."
      end
      message = " The soil seems less fertile than last year."
    end
  end

  mysql_update("grid", {"x" => tile["x"], "y" => tile["y"]}, {"terrain" => 91, "building_hp" => 0})
  mysql_change_inv(user, item_id, -10)
  mysql_change_ap(user, -15)
  mysql_give_xp(:herbal, 5, user)
  mysql_put_message("persistent",
                    "$ACTOR sowed the field with wheat", user)

  "You sow the field with #{item[:plural]}.#{message}"
end

def stockpile_has_item?(x, y, item_id)
  if stockpile_item_amount(x, y, item_id) > 0 then true   else false end
end

def stockpile_item_amount(x, y, item_id)
  query = "SELECT amount FROM `stockpiles`" +
          mysql_where({"x" => x, "y" => y, "item_id" => item_id})

  result = $mysql.query(query)
  if result.count != 0
    result.first['amount'].to_i # = result['amount']
  else
    0
  end
end

def sum_coll(coll)
  array = coll.to_a
  case array.length
  when 0
    0
  when 1
    array[0]
  when 2
    array[0] + array[1]
  else
    array[0] + sum_coll(array.slice(1..array.length))
  end
end

def take(user_id, amount, item_id, magic)
  return "Error. Try again." if magic != $user.magic
  user = User.new(user_id)
  stockpile = user.tile.building
  unless stockpile.item_storage?
    return "There is nothing you can take here."
  end

  if item_id == nil then return "You take nothing." end

  if user.hp == 0
    return "You can't take items while dazed."
  end

  if weight(user) >= Max_Weight
    return "You already have as much as you can carry."
  end

  stockpile_settlement = user.tile.settlement
  if stockpile_settlement and stockpile_settlement != user.settlement
    return "You are not a citizen of #{stockpile_settlement.name}, " +
             "and cannot take items from their stockpile."
  end

  if amount.to_i < 1 || amount.to_i > 5 then return "That's an invalid quantity to take." end

  amt_taken = -mysql_change_inv(stockpile, item_id, -amount.to_i)
  mysql_change_inv(user_id, item_id, +amt_taken)
  if amt_taken == 0
    return "There aren't any #{db_field(:item, item_id, :plural)} " +
             "in the stockpile."
  end

  items_desc = describe_items(amt_taken, item_id, :long)
  mysql_change_ap(user_id, -1)
  mysql_put_message("persistent",
                    "$ACTOR took #{items_desc} from the stockpile", user_id)
  "You take #{items_desc} from the stockpile."
end

def tile_dir(user, tile)
  # What direction is tile from user?

  x_offset = tile.x - user.x
  y_offset = tile.y - user.y

  if user.z == 0
    unless user.tile == tile
      return offset_to_dir(x_offset, y_offset, 0)
    end
    if valid_location?(tile.x, tile.y, 1) then "Enter"     else nil end
  else
    if user.tile == tile then "Exit"     else nil end
  end
end

def transfer_frags(attacker, target)
  frags = (target.frags / 2.0).ceil
  mysql_bounded_update("accounts", "frags", attacker.mysql_id, +frags)
  mysql_bounded_update("accounts", "frags", target.mysql_id, -frags, 0)
  if frags != 0
    "$TARGET lost #{describe_number(frags)} " +
      "frags; they have been transferred to $ACTOR."
  else
    ""
  end
end

def upcase_first(str)
  str[0] = str[0] - 32 if str[0] >= 97 and str[0] <= 122 # 97, 122 = ascii(a, z)
  str
end

def use(user, target, item_id, magic)
  return "Error. Try again." if magic != $user.magic
  unless target.exists? then target = user end

  unless same_location?(user, target)
    return "That person isn't in the vicinity."
  end
  item = db_row(:item, item_id)
  if item.nil?
    return "Nothing happens."
  end
  unless user_has_item?(user, item_id)
    return "You don't have any #{item[:plural]}."
  end

  item_desc = a_an(item[:name])
  if item[:use].kind_of? String then return item[:use] end
  case item[:use]
  when nil
    "You try using #{a_an(item[:name])}, but it doesn't seem to achieve much."
  when :weapon
    "Use the 'Attack' button to attack."
  when :food
    feed(user.mysql_id, target.mysql_id, item_id)
  when :heal
    heal(user, target, item_id)
  when :noobcake
    if target.level > 1
      if user == target
        "Suddenly the sickly sweet noobcakes don't seem quite so " +
          "tempting anymore. Try finding a different source of food."
      else
        "You offer a noobcake to #{target.name}. " +
          "They wrinkle their nose in disgust."
      end
    else
      feed(user.mysql_id, target.mysql_id, item_id) +
        if user == target
          " You particularly enjoy the sugary frosting - it's decorated " +
          "with a picture of a cuddly bear surrounded by hearts."
        else ""         end
    end
  when :ocarina
    ocarina(user, target, item_id)
  when :revive
    revive(user.mysql_id, target.mysql_id, item_id)
  end
end

def user_actions(user)
  # returns an array containing the forms to display for user
  tile = user.tile
  forms = []
  if can_act?(user)
    if user.hp > 0
      forms << :attack
      forms << :build
      forms << :craft
      forms << :write if tile.building_id != 0
      building_forms = db_field(:building, tile.building_id, :actions)
      forms += building_forms if building_forms != nil
      tile_forms = db_field(:terrain, tile.terrain, :actions)
      forms += tile_forms if tile_forms != nil
    else
      forms << :offer
    end
    forms << :search
    forms << :give
    forms << :use
    forms << :drop
    forms << :speak
  elsif user.ap < 1
    forms << :no_ap
  else
    forms << :no_ip
  end
  forms
end

def user_has_item?(user, item_id)

  # Delete this after OOP refactoring
  user_id =
    if user.kind_of?(Integer) || user.kind_of?(String)
      user
    else
      user.mysql_id
    end

  if item_id == nil || item_id == "24" # 24 -> fist
    return true
  end

  if item_id.is_a?(Array)
    item_id.each do |item|
      unless user_has_item?(user, item) then return false end
    end
    return true
  end

  if item_id.is_a?(Hash)
    item_id.each do
      |item, amt|
      if user_item_amount(user, item) < amt then return false end
    end
    return true
  end

  user_item_amount(user_id, item_id) > 0
end

def user_item_amount(user, item_id)

  # Delete this after OOP refactoring
  user_id =
    if user.kind_of?(Integer) || user.kind_of?(String)
      user.to_i
    else
      user.mysql_id
    end

  if item_id.is_a?(Symbol)
    item_id = db_field(:item, item_id, :id)
  end

  query = "SELECT amount FROM `inventories`" +
          mysql_where({"user_id" => user_id, "item_id" => item_id})
  result = $mysql.query(query)
  if result.count != 0
    result.first['amount'].to_i # = result['amount']
  else
    0
  end
end

def validate_user(user_id, password)
  user = User.new(user_id)
  return false unless user.exists?
  db_password = user.password
  if db_password == password then return true   else false end
end

def valid_location?(x, y, z)
  tile = mysql_tile(x, y)
  floors = db_field(:building, tile["building_id"], :floors)
  if floors == nil then floors = 0 end
  (0..floors).include? z
end

def values_freqs_hash(mysql_resource, field)
  hash = Hash.new
  hash.default = 0
  mysql_resource.each do |row|
    value = row[field]
    hash[value] += 1
  end
  hash
end

def vote(voter, candidate)
  if $params["magic"] != $user.magic
    return "Error. Try again."
  end
  if voter.settlement == nil && voter.temp_sett_id == 0
    return "You are not currently a member of any settlement."
  end

  if candidate.mysql_id == 0
    mysql_update("accounts", voter.mysql_id,
                 {"vote" => candidate.mysql_id})
    return "As none of the candidates suit your fancy, you choose to support no one."
  end

  if candidate.settlement == nil
    return "You cannot support that person."
  end

  unless (voter.settlement == candidate.settlement || voter.temp_sett_id == candidate.settlement.mysql_id)
    return "You cannot support that person."
  end

  settlement = voter.settlement
  mysql_update("accounts", voter.mysql_id,
               {"vote" => candidate.mysql_id})
  "You pledge your support for <b>#{candidate.name}</b> as #{candidate.settlement.title} " +
    "of #{candidate.settlement.name}."
end

def water(user, magic)
  return "Error. Try again." if magic != $user.magic
  tile = user.tile
  return "You cannot water here." unless tile.actions.include?(:water)
  unless user_has_item?(user, :water_pot)
    return "You dont have any water."
  end

  if season == :Spring || season == :Summer
    growth = ((tile.hp + 1) / 3).to_i + 4 #5 at 2 or 3 hp, 4 at 1 hp
  else
    return "You don't need to water at this time of year."
  end

  mysql_bounded_update("grid", "building_hp", tile.mysql_id, +growth)
  mysql_bounded_update("grid", "terrain", tile.mysql_id, 1) # change tile to "watered field"
  mysql_change_inv(user, :water_pot, -1)
  mysql_change_inv(user, :pot, +1)
  mysql_change_ap(user, -1)
  mysql_give_xp(:herbal, 1, user)

  "You pour a pot of water on the field. " +
  "You can almost hear the wheat growing."
end

def weight(user)
  items = db_table(:item)
  weight = 0
  items.each do
    |item, info|
    amount = user_item_amount(user, item)
    weight += (amount * info[:weight]) if info[:weight] != nil
  end
  weight
end

def write(user, msg, magic)
  return "Error. Try again." if magic != $user.magic
  building = Building.new(user.x, user.y)
  unless building.exists?
    return "There is no building to write on in the vicinity."
  end

  if user.hp == 0
    return "You don't have the cognizance to write while dazed."
  end

  if building.unwritable
    return "You cannot write on #{building.a}."
  end

  unless user_has_item?(user, :hand_axe) ||
         user_has_item?(user, :stone_carpentry)
    return " You need a hand axe or a set of stone carpentry tools " +
             "to write on the building."
  end

  mysql_change_ap(user, -3)
  msg = CGI::escapeHTML(msg)
  # check for existing messages
  if mysql_row("writings", {"x" => user.x, "y" => user.y, "z" => user.z}) == nil
    mysql_insert("writings",
                 {"x" => user.x, "y" => user.y, "z" => user.z, "message" => msg})
  else
    mysql_update("writings",
                 {"x" => user.x, "y" => user.y, "z" => user.z}, {"message" => msg})
  end

  mysql_put_message("persistent",
                    "$ACTOR wrote \"#{msg}\" on #{building.a}", user.mysql_id)
  "You write \"#{msg}\" on #{building.name}."
end

def xp_field(type)
  case type
  when :herbalist then "herbal_xp"
  when :crafter then "craft_xp"
  when :wanderer then "wander_xp"
  when :warrior then "warrior_xp"
  else nil
  end
end

def you_or_her(you_id, her_id, you = "you", link = :link)
  # exactly the same as the function below, but I didn't like
  # having a gender-biased codebase. It's the 21st century.
  you_or_him(you_id, her_id, you, link)
end

def you_or_him(you_id, him_id, you = "you", link = true)
  if you_id.to_i == him_id.to_i
    "<b>#{you}</b>"
  else
    him = mysql_user(him_id)
    return "" if him == nil
    if link != :no_link then html_userlink(him_id, him["name"])     else him["name"] end
  end
end
