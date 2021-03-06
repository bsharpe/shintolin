require 'yaml'
require 'json'
require 'ostruct'

def db
  @db ||= begin
    db_config = JSON.parse(YAML.load_file('../db/database.yml').to_json, object_class: OpenStruct).send(ENV['GAME_ENV'])

    Mysql2::Client.new(
      host: db_config.host,
      username: db_config.username,
      password: db_config.password,
      database: db_config.database
    )
  end
rescue StandardError => e
  # print "Error code: ", e.errno, "\n"
  puts "Error message: #{e}".yellow
end

def mysql_transaction
  db.query('BEGIN WORK;')
  yield
  db.query('COMMIT;')
end

def mysql_bounded_update(table, field, where_clause, change, bound = nil)
  bound ||= change.positive? ? 9_999_999 : 0
  bound = bound.to_i

  current_amount = mysql_row(table, where_clause)[field].to_f

  if change.positive?
    # if change is positive, treat bound as an upper bound
    if (current_amount + change) > bound
      change = [bound - current_amount, 0].max
    end
  elsif change.negative?
    # if change is negative, treat bound as a lower bound
    if (current_amount + change) < bound
      change = [current_amount - bound, 0].max
    end
  end

  mysql_update(table, where_clause, field => current_amount + change) if !change.zero?

  change
end

def mysql_change_ap(user, change)
  user_id =
    if user.is_a?(Integer) || user.is_a?(String)
      user
    else
      user.mysql_id
    end

  # don't charge the admins any Action Point costs
  return if current_user.is_admin?

  if change.positive?
    mysql_bounded_update('users', 'ap', user_id, change, Max_AP)
  else
    mysql_bounded_update('users', 'ap', user_id, change, -Max_AP)
    if (current_user.ap + change) < -10
      ip_hit(user_id, current_user.ap * 10 + 90)
    else
      ip_hit(user_id, -(change * 10) - 10)
    end
  end
end

def mysql_change_stat(user, stat, amt)
  mysql_bounded_update('accounts', stat, user.mysql_id, amt)
end

def mysql_change_inv(inv, item_id, amt)
  # OOP refactoring needed!
  table = 'inventories'
  case inv.class.name
  when 'Fixnum', 'String'
    row_id = { user_id: inv }
  when 'User'
    table = 'inventories'
    row_id = { user_id: inv.mysql_id }
  when 'Building'
    table = 'stockpiles'
    row_id = inv.mysql_id
  when 'Tile'
    table = 'stockpiles'
    row_id = inv.mysql_id
  end

  item_id = lookup_table_row(:item, item_id, :id) if item_id.is_a?(Symbol)

  row_id['item_id'] = item_id
  current_amount = mysql_row(table, row_id)
  if !current_amount.nil?
    mysql_bounded_update(table, 'amount', row_id, amt, (amt >= 0) ? Max_Items : 0)
  elsif amt >= 0
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

def mysql_change_stockpile(x, y, item_id, change)
  item_id = lookup_table_row(:item, item_id, :id) if item_id.is_a?(Symbol)
  current_amount = mysql_row('stockpiles', x: x, y: y, item_id: item_id)
  if !current_amount.nil?
    current_amount = current_amount['amount'].to_i
    new_amount = current_amount + change
    if new_amount.negative?
      # if the change would set that item below 0, set that item to 0
      # and return the actual amount changed
      change = -current_amount
      mysql_update('stockpiles', { x: x, y: y, item_id: item_id }, amount: 0)
    else
      mysql_update('stockpiles',
                   { x: x, y: y, item_id: item_id }, amount: new_amount)
    end
  elsif change >= 0
    mysql_insert('stockpiles',
                 x: x, y: y, item_id: item_id, amount: change)
  else
    # if trying to reduce items the stockpile doesn't have,
    # do nothing and return 0
    change = 0
  end
  change
end

def mysql_delete(table, where_clause = nil)
  raise ArgumentError, "Can't delete everything (where_clause is nil)" if !where_clause

  db.query("DELETE FROM `#{table}` #{mysql_where(where_clause)}")
end

def mysql_insert(table, column_values_hash)
  columns = column_values_hash.keys
  values = column_values_hash.values.map{|e| mysql_value(e)}

  query = "INSERT INTO #{table} (#{columns.join(',')}) VALUES (#{values.join(',')})"
  db.query(query)
end

def mysql_select(table, where_clause, not_clause = nil)
  query = "SELECT * FROM `#{table}` #{mysql_where(where_clause, not_clause)}"
  db.query(query)
end
alias mysql_query mysql_select

def mysql_count(table, where_clause, not_clause = nil)
  query = "SELECT COUNT(*) AS count FROM `#{table}` #{mysql_where(where_clause, not_clause)}"
  db.query(query).first['count']
end

def mysql_select_all(table, options = nil)
  query = "SELECT * FROM `#{table}` #{options}"
  db.query(query)
end

def mysql_row(table, where_clause, not_clause = nil)
  query = "SELECT * FROM `#{table}` #{mysql_where(where_clause, not_clause)} LIMIT 1"
  db.query(query).first
end

def mysql_tile(x, y)
  mysql_row('grid', x: x, y: y) || { x: x, y: y, terrain: 3, region_id: 3, building_id: 0, hp: 3, building_hp: 0 }
end

def mysql_update(table, where_clause, column_values_hash, not_clause = nil)
  updates = column_values_hash.each_with_object([]) do |(column, value), result|
    result << "`#{column}` = #{mysql_value(value)}"
  end

  query = "UPDATE `#{table}` SET #{updates.join(',')} #{mysql_where(where_clause, not_clause)}"
  db.query(query)
end

def mysql_value(value)
  case value
  when :Today
    'UTC_DATE()'
  when :Now
    'NOW()'
  else
    "'#{db.escape(value.to_s)}'"
  end
end

def mysql_where(clause, not_clause = nil)
  # if passed an integer, returns 'WHERE id = clause
  # if passed a hash map, returns 'WHERE key1 = value1, key2 = value2..."
  case clause
  when Integer, String
    # assume where_clause is an id value
    clause = clause.to_i
    " WHERE `id` = '#{clause}'"

  when Hash
    result = ' WHERE'
    where_array = clause.map do |column, value|
      if !value.is_a?(Enumerable)
        " `#{column}` = #{mysql_value(value)}"
      else
        # if hash->value is "x => [1,2,3]", query should be
        # WHERE ('x' in(1,2,3))
        "(`#{column}` in(#{value.map{|e| mysql_value(e)}.join(',')}))"
      end
    end
    result << where_array.join(' AND ')

    if !not_clause.nil?
      result << ' AND NOT ('
      not_array = not_clause.map do |column, value|
        "`#{column}` = #{mysql_value(value)}"
      end
      result << not_array.join(' AND ') + ')'
    end
    result
  else
    puts "ERROR: argument[#{clause.class}] to mysql_where_clause must be an integer or hash."
    ' WHERE FALSE'
  end
end
