class Tile < Base
  def self.mysql_table
    'grid'
  end

  data_fields 'actions'

  mysql_int_fields 'mysql', 'terrain', 'building_id', 'region_id', 'hp', 'building_hp', 'id'

  attr_reader :x, :y

  def initialize(x, y)
    @x = x.to_i
    @y = y.to_i
    @mysql_id = { 'x' => x, 'y' => y }
  end

  def terrain
    mysql['terrain'] || 3
  end

  def ==(other)
    x == other.x && y == other.y
  end

  def building
    @building ||= Building.new(tile: self)
  end

  def has_building?
    building_id.positive?
  end

  def data
    @data ||= lookup_table_row(:terrain, terrain)
  end

  def altitude
    data[:altitude].to_i
  end

  def description(z = 0)
    if z.zero?
      desc = lookup_table_row(:terrain, terrain, season) || lookup_table_row(:terrain, terrain, :description)
      desc = "#{desc} #{building.description(z)}"
      if terrain == 3
        dir = offset_to_dir(-x.to_1, -y.to_1, 0, :long)
        desc += " Civilisation is somewhere to the #{dir}."
      end
    else
      desc = building.description(z).to_s
    end
    desc
  end

  def exists?
    !mysql_row('grid', 'x' => x, 'y' => y).nil?
  end

  def image
    image = lookup_table_row(:terrain, terrain, :image)
    if image.is_a?(Hash)
      image = if !image[season].nil?
                image[season]
              else
                image[:default]
              end
    end
    image = lookup_table_row(:terrain, :wilderness, :image) if image.nil?
    image
  end

  def mysql
    @mysql ||= mysql_tile(@x, @y)
  end

  def region_name
    lookup_table_row(:region, region_id, :name)
  end

  def settlement_id
    if @settlement_id.nil?
      @settlement_id = false
      @settlement = false
      settlement = mysql_row('settlements', 'x' => (x - 2..x + 2), 'y' => (y - 2..y + 2))
      unless settlement.nil?
        # there's a settlement in the area, but is it close enough?
        x_offset = settlement['x'].to_i - x
        y_offset = settlement['y'].to_i - y
        if (x_offset * x_offset) + (y_offset * y_offset) <= 5
          @settlement_id = settlement['id'].to_i
          @settlement = Settlement.new(@settlement_id)
        end
      end
    end
    @settlement_id
  end

  def settlement
    settlement_id ? @settlement : nil
  end

  def update(**params)
    mysql_update(self.class.mysql_table, { x: x, y: y }, params)
  end

  def change_inv(item_id, amount)
    if amount.positive?
      if (row = mysql_row('stockpiles', x: x, y: y, item_id: item_id))
        mysql_update('stockpiles', { x: x, y: y, item_id: item_id }, amount: row['amount'].to_i + amount)
      else
        mysql_insert('stockpiles', x: x, y: y, item_id: item_id, amount: amount)
      end
    elsif (row = mysql_row('stockpiles', x: x, y: y, item_id: item_id))
      if row['amount'].to_i - amount <= 0
        mysql_delete('stockpiles', x: x, y: y, item_id: item_id)
      else
        mysql_update('stockpiles', { x: x, y: y, item_id: item_id }, amount: row['amount'].to_i - amount)
      end
    else
      mysql_insert('stockpiles', x: x, y: y, item_id: item_id, amount: amount)
    end
  end
end
