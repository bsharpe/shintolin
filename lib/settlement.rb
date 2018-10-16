# frozen_string_literal: true

class Settlement < Base
  def self.mysql_table
    'settlements'
  end

  mysql_int_fields 'mysql', 'x', 'y', 'leader_id', 'allow_new_users'

  mysql_fields 'mysql', 'name', 'motto', 'title', 'type',
               'founded', 'website'

  def ==(settlement)
    settlement.class == Settlement && settlement.mysql_id == mysql_id
  end

  def description
    mysql['description'].present? ? mysql['description'] : "A #{type} located in #{region_name}."
  end

  def image
    mysql['image'].present? ? http(mysql['image']) : 'images/p_huts_small.jpg'
  end

  def pending_ids
    query = 'SELECT `accounts`.`id` ' \
            'FROM `users` , `accounts` ' \
            'WHERE `users`.`id` = `accounts`.`id` ' \
            "AND `accounts`.`temp_sett_id` = '#{mysql_id}' " \
            "AND `users`.`active` = '1'"
    db.query(query).each_with_object([]) { |row, result| result << row['id'] }
  end

  def pendings
    pending_ids.map { |id| User.new(id) }
  end

  def pending_links
    pendings.map(&:link)
  end

  #  def pending_names
  #    pendings.map {|user| user.name}
  #  end

  def inhabitant_ids
    query = 'SELECT `accounts`.`id` ' \
            'FROM `users` , `accounts` ' \
            'WHERE `users`.`id` = `accounts`.`id` ' \
            "AND `accounts`.`settlement_id` = '#{mysql_id}' " \
            "AND `users`.`active` = '1' ORDER BY `accounts`.`when_sett_joined`,`accounts`.`id` ASC"
    db.query(query).each_with_object([]) { |row, result| result << row['id'] }
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

  def leader
    @leader ||= User.new(leader_id)
  end

  def leader_link
    @leader_link ||= leader ? leader.link : 'None'
  end

  def leader_name
    @leader_name ||= leader ? leader.name : 'None'
  end

  def link
    if exists?
      desc = description
      desc = description.slice(0, 140) + '...' if desc.length > 140
      desc.tr!('"', '\'') # double - single quotes

      relation =
        !$user.nil? ? $user.relation(self) : 'neutral'
      "<a href=\"settlement.cgi?id=#{mysql_id}\" " \
        "class=\"#{relation}\" " \
        "title=\"#{desc}\" " \
        ">#{name}</a>"
    else
      '<i>None</i>'
    end
  end

  def population
    inhabitant_ids.nitems
  end

  def tile
    @tile ||= Tile.new(x, y)
  end

  def region_id
    tile.region_id
  end

  def region_name
    tile.region_name
  end
end
