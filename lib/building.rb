require 'base'

class Building < Base
  def self.mysql_table
    'grid'
  end

  def self.lookup_table
    'building'
  end

  data_fields 'floors', 'max_hp', 'ap_recovery', 'build_ap',
              'build_xp', 'build_skill', 'materials', 'build_msg', 'actions',
              'special', 'prereq', 'tools', 'unwritable', 'name', 'interior',
              'use_skill', 'effect_bonus', 'craft_ap_bonus', 'accuracy_bonus',
              'id'

  attr_reader :x, :y

  def initialize(x = nil, y = nil, tile: nil)
    if tile.nil?
      @x = x.to_i
      @y = y.to_i
    else
      @x = tile.x
      @y = tile.y
      @tile = tile
    end
    @id = { x: x, y: y }
  end

  def a
    a_an(name_only)
  end

  def hp
    mysql['building_hp'].to_i
  end

  def description(z = 0)
    return '' if !exists?

    dmg = case (hp.to_f / max_hp)
          when (0...0.33)
            building_code == :campfire ? 'dying ' : 'ruined '
          when (0.33...0.67)
            building_code == :campfire ? '' : 'damaged '
          when (0.67...1)
            building_code == :campfire ? 'roaring ' : 'dilapidated '
          else
            building_code == :campfire ? 'raging ' : ''
          end

    if z.zero?
      desc = "There is #{a_an(dmg + data[:name])} here"
    else
      desc = interior
      desc = "You are inside #{a_an(dmg + data[:name])}" if desc.nil?
    end

    if item_storage?
      desc << ', containing: <span class="small">'
      contents, = html_inventory(x, y, ' ', :commas, :inline)
      desc << contents
      desc << '</span>'
    end
    desc << 'nothing' if contents == "\n"
    desc << '.'

    writing = writing(z)
    if writing
      t_name = "the wall"
      t_name = name if z.zero?
      desc << " Written on #{t_name} are the words <i>\"#{writing}\"</i>"
    end
    desc
  end

  def data
    @data ||= lookup_table_row(self.class.lookup_table, mysql['building_id']) || {}
  end

  def description(_z)
    data[:description]
  end

  def building_id
    mysql['building_id'].to_i
  end

  def building_code
    data[:name].to_sym
  end

  def exists?
    building_id.positive?
  end

  def item_storage?
    !actions.nil? && actions.include?(:take)
  end

  def improvements
    if exists?
      return [repair] if hp < max_hp && building_code != :campfire

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
    !prereq.nil? ? lookup_table_row(self.class.lookup_table, prereq, :id) : 0
  end

  def repair
    repair = data.clone
    return repair if max_hp.zero?

    multiplier =
      case (hp.to_f / max_hp)
      when (0...0.33) then 0.66
      when (0.33...0.67) then 0.33
      else
        0
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
    case special
    when :settlement
      settlement = tile.settlement
      return "#{settlement.name}, population #{settlement.population}. #{settlement.motto}"
    else
      writing = mysql_row('writings', x: x, y: y, z: z) || {}
      writing['message']
    end
  end
end
