require 'base'

class Animal < Base
  data_fields 'attack_odds', 'attack_dmg', 'habitats', 'hit_msg', 'loot',
              'max_hp', 'when_attacked', 'loot_bonus', 'immobile'

  mysql_int_fields 'mysql', 'x', 'y', 'z', 'hp', 'type_id', 'id'

  def self.mysql_table
    'animals'
  end

  def self.lookup_table
    :animal
  end

  def self.at_location(x, y)
    mysql_select(self.mysql_table, x: x, y: y).map do |row|
      self.new(row: row)
    end
  end
end
