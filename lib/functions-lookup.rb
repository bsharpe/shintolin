# frozen_string_literal: true

def lookup_table(table)
  $Data[table] || {}
end

def lookup_row_where(table, column, value)
  (lookup_table(table).values || []).detect { |row| row[column] == value }
end

def lookup_table_row(table, row, field = nil)
  record = if row.is_a?(Integer) || row.is_a?(String)
             lookup_row_where(table, :id, row.to_i)
           else
             lookup_table(table)[row]
    end || {}
  field ? record[field.to_sym] : record
end

def lookup_all_where(table, column, value)
  lookup_table(table).values.find_all { |row| row[column] == value }
end
