class User < Base
  def self.mysql_table
    'users'
  end

  mysql_fields "mysql", "name", "lastaction", "password"

  mysql_float_fields "mysql", "ap"

  mysql_int_fields "mysql", "x", "y", "z", "hp", "maxhp", "hunger",
    "wander_xp", "herbal_xp", "combat_xp", "craft_xp", "active", "is_admin"

  mysql_int_fields "mysql_2", "settlement_id", "temp_sett_id",
    "frags", "kills", "deaths", "revives", "vote"


  def self.find_by_username(username)
    user = mysql_row('users', 'name' => username) || {}
    self.new(user['id']) if user['id']
  end

  def validate(password)
    BCrypt::Password.new(self.password) == password
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

  def last_revive
    Time.str_to_time(mysql_2["last_revive"]).ago
  end

  def level(type = :all)
    if type == :all
      skills = lookup_table(:skill).values
    else
      skills = lookup_all_where(:skill, :type, type)
    end
    level = 0
    skills.each { |skill| level += 1 if self.has_skill?(skill[:id]) }
    level
  end

  def link
    html_userlink(mysql_id, name)
  end

  def mysql_2
    @mysql_2 ||= mysql_row("accounts", @mysql_id)
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
    @tile = Tile.new(self.x, self.y)
  end

  def magic
    "#{self.lastaction.to_i}:#{self.name}"
  end

  def give_xp(kind, value)
    value = rand_to_i(value) if value.is_a?(Float)
    value = value&.abs || 0
    mysql_bounded_update(self.class.mysql_table, "#{kind}_xp}".to_sym, self.id, value, 1000)
  end

  def change_ap(value)
    mysql_change_ap(self.id, value)
  end

  def item_count(item_id)
    if item_id.is_a?(Symbol)
      item_id = lookup_table_row(:item, item_id, :id)
    end
    query = "SELECT amount FROM `inventories`" + mysql_where({"user_id" => self.id, "item_id" => item_id})
    result = db.query(query)
    result.count != 0 ? result.first['amount'].to_i : 0
  end

  def has_item?(item_id)
    self.item_count(item_id).positive?
  end

  def has_all_items?(item_list)
    item_list.map{|e| self.has_item?(e)}.all?
  end

  def change_inv(item_id, delta)
    mysql_change_inv(self.id, item_id, delta)
  end

  def outside?
    self.z.zero?
  end

  def inside?
    !outside?
  end

  def weight
    weight = 0
    items = lookup_table(:item) || []
    items.each do |item, info|
      amount = self.item_count(item)
      weight += amount * (info[:weight].to_f)
    end
    weight
  end

  def skills
    db.query("SELECT * FROM `skills` WHERE `user_id` = #{self.id}")
  end

  def has_skill?(skill_id)
    return true if skill_id == 0 || skill_id == nil || skill_id == :default

    skill_id = lookup_table_row(:skill, skill_id, :id) if skill_id.is_a?(Symbol)

    !!mysql_row("skills", {user_id: self.id, skill_id: skill_id})
  end

  def others_at_location
    mysql_select(self.class.mysql_table, { x: self.x, y: self.y, z: self.z, active: 1 }, id: self.id)
  end

end