class Base
  attr_reader :mysql_id, :mysql

  def self.find(id)
    new(row: mysql_row(mysql_table, id.to_i))
  end

  def self.ensure(thing)
    case thing
    when NilClass
      nil
    when self
      thing
    when String, Integer
      new(thing)
    end
  end

  def initialize(id = nil, row: nil)
    @mysql_id = id.to_i
    if row
      @mysql = row
      @mysql_id = row['id']
    end
  end

  def delete
    mysql_delete(self.class.mysql_table, self.mysql_id)
  end

  def ==(other)
    other.class == self.class && other.mysql_id == mysql_id
  end

  def self.max_id
    query = "SELECT MAX(`id`) FROM `#{mysql_table}`"
    db.query(query).first['MAX(`id`)'].to_i
  end

  def self.mysql_table
    'unknown'
  end

  def self.lookup_table
    'unknown'
  end

  def id
    @mysql_id
  end

  def [](value)
    mysql[value]
  end

  def exists?
    mysql != nil
  end

  def mysql
    @mysql ||= mysql_row(self.class.mysql_table, mysql_id)
  end

  def update(**params)
    mysql_update(self.class.mysql_table, { id: id }, params)
  end

  def reload!
    @mysql = nil
    mysql
    self
  end

  def name
    data[:name]
  end

  def lookup_data
    @lookup_data ||= lookup_table_row(self.class.lookup_table, mysql['type_id'])
  end

  def self.data_fields(*fields)
    fields.each do |field|
      class_eval %(
        def #{field}
	        data[:#{field}]
	      end
      )
    end
  end

  def self.mysql_fields(method = 'mysql', *fields)
    fields.each do |field|
      class_eval %(
        def #{field}
	        #{method}['#{field}']
	      end
      )
    end
  end

  def self.mysql_int_fields(method = 'mysql', *fields)
    fields.each do |field|
      class_eval %(
        def #{field}
	        #{method}['#{field}'].to_i
	      end
      )
    end
  end

  def self.mysql_float_fields(method = 'mysql', *fields)
    fields.each do |field|
      class_eval %(
        def #{field}
	        #{method}['#{field}'].to_f
	      end
      )
    end
  end
end
