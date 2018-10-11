# frozen_string_literal: true

def mysql_bounded_update(table, field, where_clause, change, bound = nil)
  if bound.nil?
    bound = if change > 0 then 1_000_000 # an arbitrarily large number
            else 0 end
  end
  bound = bound.to_i
  current_amt = mysql_row(table, where_clause)[field].to_f
  return 0 if change == 0

  if change > 0
    # if change is positive, treat bound as an upper bound
    if (current_amt + change) < bound
      mysql_update(table, where_clause, field => (current_amt + change))
      change
    else
      mysql_update(table, where_clause, field => bound)
      bound - current_amt # actual amount changed
    end
  else
    # if change is negative, treat bound as a lower bound
    if (current_amt + change) > bound
      mysql_update(table, where_clause, field => (current_amt + change))
      change
    else
      mysql_update(table, where_clause, field => bound)
      bound - current_amt # actual amount changed
    end
  end
end

def mysql_change_ap(user, change)
  user_id =
    if user.is_a?(Integer) || user.is_a?(String)
      user
    else
      user.mysql_id
    end

  if change > 0
    mysql_bounded_update('users', 'ap', user_id, change, Max_AP)
  else
    mysql_bounded_update('users', 'ap', user_id, change, -Max_AP)
    if $user.ap + change < -10 then ip_hit(user_id, $user.ap * 10 + 90)
    else ip_hit(user_id, -(change * 10) - 10) end
  end
end

def mysql_change_stat(user, stat, amt)
  mysql_bounded_update('accounts', stat, user.mysql_id, amt)
end

def mysql_change_inv(inv, item_id, amt)
  # OOP refactoring needed!
  table = 'inventories'
  case inv.class.name
  when 'Fixnum' then row_id = { 'user_id' => inv }
  when 'String' then row_id = { 'user_id' => inv }
  when 'User'
    table = 'inventories'
    row_id = { 'user_id' => inv.mysql_id }
  when 'Building'
    table = 'stockpiles'
    row_id = inv.mysql_id
  when 'Tile'
    table = 'stockpiles'
    row_id = inv.mysql_id
  end

  item_id = db_field(:item, item_id, :id) if item_id.is_a?(Symbol)

  row_id['item_id'] = item_id
  current_amount = mysql_row(table, row_id)
  if !current_amount.nil?
    if amt >= 0
      mysql_bounded_update(table, 'amount', row_id, amt, Max_Items)
    else
      mysql_bounded_update(table, 'amount', row_id, amt, 0)
    end
  else
    if amt >= 0
      # add new record if one doesn't exist,
      # create one for this inventory-item combo
      row_id['amount'] = amt
      mysql_insert(table, row_id)
      amt
    else
      # if trying to reduce items the user doesn't have, do nothing and return 0
      0
    end
  end
end

def mysql_change_stockpile(x, y, item_id, change)
  item_id = db_field(:item, item_id, :id) if item_id.is_a?(Symbol)
  current_amount = mysql_row('stockpiles', 'x' => x, 'y' => y, 'item_id' => item_id)
  if !current_amount.nil?
    current_amount = current_amount['amount'].to_i
    new_amount = current_amount + change
    if new_amount < 0
      # if the change would set that item below 0, set that item to 0
      # and return the actual amount changed
      change = -current_amount
      mysql_update('stockpiles', { 'x' => x, 'y' => y, 'item_id' => item_id }, 'amount' => 0)
    else
      mysql_update('stockpiles',
                   { 'x' => x, 'y' => y, 'item_id' => item_id }, 'amount' => new_amount)
    end
  else
    if change >= 0
      mysql_insert('stockpiles',
                   'x' => x, 'y' => y, 'item_id' => item_id, 'amount' => change)
    else
      # if trying to reduce items the stockpile doesn't have,
      # do nothing and return 0
      change = 0
    end
  end
  change
end

def mysql_delete(table, where_clause = nil)
  if where_clause.nil?
    return "ERROR: You're trying to delete everything. That's probably stupid."
  end

  query = "DELETE FROM `#{table}`" +
          mysql_where(where_clause)
  if $mysql_debug then puts query
  else $mysql.query(query)
  end
end

def mysql_get_messages(x, y, z, user)
  query = 'SELECT * FROM `messages` WHERE ' +

          # spoken, whispered, game, /me or actions visible to all at same x, y, z
          "((`type` = 'talk' OR `type` = 'whisper' " \
          "OR `type` = 'slash_me' OR `type` = 'game' " \
          "OR `type` = 'visible_all')" \
          "AND `x` = '#{x}' AND `y` = '#{y}' AND `z` = '#{z}' " \
          "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

          # shouted or distant at same x, y
          " OR ((`type` = 'shout' OR `type` = 'distant') AND " \
          "`x` = '#{x}' AND `y` = '#{y}'" \
          "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

          # action targeted at player
          " OR (`type` = 'action' AND `target_id` = '#{user.mysql_id}'" \
          "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

          # persistent messages at same x, y, z
          " OR (`type` = 'persistent' AND " \
          "`x` = '#{x}' AND `y` = '#{y}' AND `z` = '#{z}'" \
          "AND (`time` + INTERVAL 24 HOUR) > '#{user.lastaction}')" \
          ' ORDER BY `time`'

  messages = $mysql.query(query)
end

def mysql_give_xp(type, xp, user)
  user_id =
    if user.is_a?(Integer) || user.is_a?(String)
      user
    else
      user.mysql_id
    end

  xp_field = case type
             when :wander then 'wander_xp'
             when :craft then 'craft_xp'
             when :herbal then 'herbal_xp'
             when :warrior then 'warrior_xp'
  end
  xp = rand_to_i(xp) if xp.is_a?(Float)
  xp = xp.abs || 0
  mysql_bounded_update('users', xp_field, user_id, +xp, 1000)
end

def mysql_insert(table, column_values_hash)
  # query "INSERT INTO grid (x,y,terrain) VALUES ('101','87','2')
  columns = column_values_hash.keys
  values = column_values_hash.values
  query = "INSERT INTO #{table} (" +
          columns.join(',')
  query += ') VALUES ('
  values = values.map do |value|
    case value
    when :Today
      'UTC_DATE()'
    else
      mysql_value(value).to_s
    end
  end

  query += values.join(',') + ')'
  puts query if $mysql_debug
  $mysql.query(query)
end

def mysql_max_id(table)
  query = "SELECT MAX(`id`) FROM `#{table}`"
  result = $mysql.query(query)
  result.first['MAX(`id`)'].to_i
end

def mysql_put_message(type, message, speaker = nil, target = nil)
  # Delete this after OOP refactoring
  speaker_id =
    if speaker.nil?
      0
    elsif speaker.is_a?(Integer) || speaker.is_a?(String)
      speaker
    else
      speaker.mysql_id
    end

  target_id =
    if target.nil?
      0
    elsif target.is_a?(Integer) || target.is_a?(String)
      target
    else
      target.mysql_id
    end

  speaker = User.new(speaker_id)
  target = User.new(target_id)
  if speaker.exists?
    mysql_insert('messages',  'x' => speaker.x, 'y' => speaker.y,
                              'z' => speaker.z, 'type' => type, 'message' => message,
                              'speaker_id' => speaker_id, 'target_id' => target_id)
  else
    mysql_insert('messages',  'x' => 0, 'y' => 0,
                              'z' => 0, 'type' => type, 'message' => message,
                              'speaker_id' => 0, 'target_id' => target_id)
  end
end

def mysql_select(table, where_clause, not_clause = nil)
  query = "SELECT * FROM `#{table}`" + mysql_where(where_clause, not_clause)
  $mysql.query(query)
end
alias mysql_query mysql_select

def mysql_select_all(table)
  query = "SELECT * FROM `#{table}`"
  $mysql.query(query)
end

def mysql_row(table, where_clause, not_clause = nil)
  query = "SELECT * FROM `#{table}` #{mysql_where(where_clause, not_clause)}"
  $mysql.query(query).first
end

def mysql_tile(x, y)
  tile = mysql_row('grid', 'x' => x, 'y' => y)
  if tile.nil?
    tile = { 'x' => x, 'y' => y, 'terrain' => '3', 'region_id' => '3', 'building_id' => '0',
             'hp' => 3, 'building_hp' => 0 }
  end
  tile
end

def mysql_update(table, where_clause, column_values_hash, not_clause = nil)
  # query = "UPDATE users SET x = 9, y = 8, z = 0 WHERE id = 77"
  query = "UPDATE `#{table}` SET"
  updates_array = column_values_hash.map do |column, value|
    " `#{column}` = #{mysql_value(value)}"
  end
  query += updates_array.join(',')
  query += mysql_where(where_clause, not_clause)
  if $mysql_debug then puts query
  else $mysql.query(query)
  end
end

def mysql_user(id)
  mysql_row('users', id.to_i)
end

def mysql_user_id(username)
  user = mysql_row('users', 'name' => username)
  user['id'] unless user.nil?
end

def mysql_value(value)
  case value
  when :Today then 'UTC_DATE()'
  when :Now then 'NOW()'
  else "'#{$mysql.escape(value.to_s)}'"
  end
end

def mysql_where(clause, not_clause = nil)
  # if passed an integer, returns 'WHERE id = clause
  # if passed a hash map, returns 'WHERE key1 = value1, key2 = value2..."
  clause = clause.to_i if clause.is_a?(String)
  if clause.is_a?(Integer)
    # assume where_clause is an id value
    where_clause = ' WHERE ' \
                   "`id` =  '#{clause}'"

  elsif clause.is_a?(Hash)
    where_clause = ' WHERE'
    where_array = clause.map do |column, value|
      if !value.is_a?(Enumerable)
        " `#{column}` = #{mysql_value(value)}"
      else
        # if hash->value is "x => [1,2,3]", query should be
        # WHERE ('x' = 1 OR 'x' = 2 OR 'x' = 3)
        or_array =
          value.map { |v| "`#{column}` = #{mysql_value(v)}" }
        or_clause = " (#{or_array.join(' OR ')})"
      end
    end
    where_clause += where_array.join(' AND')

    unless not_clause.nil?
      where_clause += ' AND NOT ('
      not_array = not_clause.map do |column, value|
        "`#{column}` = #{mysql_value(value)}"
      end
      where_clause += not_array.join(' AND ') + ')'
    end
  else
    puts 'ERROR: argument to mysql_where_clause must be an integer or hash.'
    where_clase = ' WHERE FALSE'
  end
  where_clause
end
