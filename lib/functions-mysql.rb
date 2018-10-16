# frozen_string_literal: true

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
rescue Exception => e
  # print "Error code: ", e.errno, "\n"
  puts "Error message: #{e}".yellow
end

def mysql_transaction
  db.query("BEGIN WORK;")
  yield
  db.query("COMMIT;")
end

def mysql_bounded_update(table, field, where_clause, change, bound = nil)
  return 0 if change == 0

  bound ||= (change > 0) ? 9_999_999 : 0
  bound = bound.to_i
  current_amt = mysql_row(table, where_clause)[field].to_f

  if change.positive?
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

  # don't charge the admins any Action Point costs
  return if $user.is_admin?

  if change.positive?
    mysql_bounded_update('users', 'ap', user_id, change, Max_AP)
  else
    mysql_bounded_update('users', 'ap', user_id, change, -Max_AP)
    if ($user.ap + change) < -10 then
      ip_hit(user_id, $user.ap * 10 + 90)
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
  when 'Fixnum','String'
    row_id = { 'user_id' => inv }
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

  item_id = lookup_table_row(:item, item_id, :id) if item_id.is_a?(Symbol)

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
  item_id = lookup_table_row(:item, item_id, :id) if item_id.is_a?(Symbol)
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
  raise ArgumentError.new("Can't delete everything (where_clause is nil)") unless where_clause

  db.query("DELETE FROM `#{table}` #{mysql_where(where_clause)}")
end

def mysql_insert(table, column_values_hash)
  columns = []
  values = []

  column_values_hash.each do |key, value|
    columns << key
    values << mysql_value(value)
  end

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

def mysql_select_all(table)
  query = "SELECT * FROM `#{table}`"
  db.query(query)
end

def mysql_row(table, where_clause, not_clause = nil)
  query = "SELECT * FROM `#{table}` #{mysql_where(where_clause, not_clause)}"
  db.query(query).first
end

def mysql_tile(x, y)
  mysql_row('grid', 'x' => x, 'y' => y) || { 'x' => x, 'y' => y, 'terrain' => '3', 'region_id' => '3', 'building_id' => '0', 'hp' => 3, 'building_hp' => 0 }
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
        or_array = value.map { |v| "`#{column}` = #{mysql_value(v)}" }
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
