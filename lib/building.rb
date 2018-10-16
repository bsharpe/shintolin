require 'base'

class Building < Base
  def self.mysql_table
    'grid'
  end

  def self.lookup_table
    'building'
  end

  data_fields "floors", "max_hp", "ap_recovery", "build_ap",
              "build_xp", "build_skill", "materials", "build_msg", "actions",
              "special", "prereq", "tools", "unwritable", "name", "interior",
              "use_skill", "effect_bonus", "craft_ap_bonus", "accuracy_bonus",
              "id"

  attr_reader :x, :y

  def initialize(x = nil, y = nil, tile: nil)
    if tile.nil?
      @x, @y = x.to_i, y.to_i
    else
      @x, @y = tile.x, tile.y
      @tile = tile
    end
    @mysql_id = {"x" => x, "y" => y}
  end

  def a
    a_an(name_only)
  end

  def hp
    mysql["building_hp"].to_i
  end

  def description(z = 0)
    return "" unless self.exists?

    dmg = case (hp.to_f / max_hp)
          when (0...0.33)
            if mysql["building_id"] == "5" then "dying "  else "ruined " end
          when (0.33...0.67)
            if mysql["building_id"] == "5" then "" else "damaged " end
          when (0.67...1)
            if mysql["building_id"] == "5" then "roaring " else "dilapidated " end
          else
            if mysql["building_id"] == "5" then "raging "else "" end
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
        desc += " Written on #{name} are the words <i>\"#{writing}\"</i>"
      else
        desc += " Written on the wall are the words <i>\"#{writing}\"</i>"
      end
    end
    desc
  end

  def data
    @data ||= lookup_table_row(self.class.lookup_table, mysql["building_id"]) || {}
  end

  def description(z)
    data[:description]
  end

  def building_id
    mysql['building_id'].to_i
  end

  def exists?
    building_id > 0
  end

  def item_storage?
    actions != nil && actions.include?(:take)
  end

  def improvements
    if self.exists?
      return [self.repair] if hp < max_hp && building_id != 5 # 5 = campfire
      key = id_to_key(:building, building_id)
    else
      key = nil
    end

    lookup_all_where(:building, :prereq, key)
  end

  def mysql
    @mysql ||= tile.mysql
  end

  def name
    "the #{data[:name]}"
  end

  def prereq_id
    (prereq != nil) ? lookup_table_row(self.class.lookup_table, prereq, :id) : 0
  end

  def repair
    repair = data.clone
    return repair if max_hp.zero?

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
    data[:materials].each do |item, amt|
      repair[:materials][item] = (amt.to_f * multiplier).to_i
    end
    repair
  end

  def tile
    @tile ||= Tile.new(x, y)
  end

  def writing(z)
    if special == :settlement
      settlement = tile.settlement
      return "#{settlement.name}, population #{settlement.population}. #{settlement.motto}"
    end
    writing = mysql_row("writings", {"x" => x, "y" => y, "z" => z}) || {}
    writing["message"]
  end
end

