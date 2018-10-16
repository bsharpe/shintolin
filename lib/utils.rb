module Utils
  def a_an(str)
    str =~ /^[aeiou].*/ ? "an #{sr}" : "a #{str}"
  end

  def encrypt(str)
    BCrypt::Password.create(str)
  end

  def skill_cost(level)
    (level + 2) * 30
  end

  def values_freqs_hash(resources, field)
    resources.each_with_object(Hash.new(0)) do |row, hash|
      hash[row[field]] += 1
    end
  end

  def minutes_to_hour
    unix_t = Time.now.to_i
    seconds_past = unix_t - ((unix_t / 3600) * 3600)
    ((3600 - seconds_past) / 60) + 1
  end

  def month
    # Ruby calculates time in seconds by GMT. To synch up with cron, we must lie and say whatever time zone
    # we're in is actually GMT, -then- calculate the seconds.
    gmt_time = Time.now.to_a
    local_time = Time.utc(gmt_time[5], gmt_time[4], gmt_time[3], gmt_time[2], gmt_time[1], gmt_time[0])

    day = local_time.to_i / (3600 * 24) % 3
    prefix =
      case day
      when 0 then 'Early '
      when 1 then 'Mid '
      when 2 then 'Late '
      end
    prefix + season.to_s
  end

  def season
    three_day_block = Time.now.utc.to_i / (3600 * 24 * 3) % 4
    case three_day_block
    when 0 then :Winter
    when 1 then :Spring
    when 2 then :Summer
    when 3 then :Autumn
    end
  end

  def game_year
    gmt_time = Time.now.to_a
    game_time = Time.utc(gmt_time[5], gmt_time[4], gmt_time[3], 0, 0, 0)
    game_time -= Time.utc(2009, 3, 28, 0, 0, 0)
    game_time.to_i / (12 * 60 * 60 * 24)
  end


  SHORT_DIRECTIONS = %w[N NW W SW S SE E NE In Out].freeze
  LONG_DIRECTIONS = %w[North Northwest West Southwest South Southeast East Northeast inside outside].freeze

  def random_dir
    SHORT_DIRECTIONS[rand(8)]
  end

  def offset_to_dir(x_offset, y_offset, z_offset = 0, length = :short)
    dirs = length == :short ? SHORT_DIRECTIONS : LONG_DIRECTIONS
    case z_offset
    when 0
      case y_offset
      when -1
        case x_offset
        when -1 then dirs[1]
        when 0 then dirs[0]
        when 1 then dirs[7]
        end
      when 0
        case x_offset
        when -1 then dirs[2]
        when 0 then nil
        when 1 then dirs[6]
        end
      when 1
        case x_offset
        when -1 then dirs[3]
        when 0 then dirs[4]
        when 1 then dirs[5]
        end
      end
    when 1 then dirs[8]
    when -1 then dirs[9]
    end
  end

  def rand_to_i(x)
    # eg, if x is 1.4, returns 1 60% of the time and 2 40% of the time
    rand < (x - x.floor) ? x.floor + 1 : x.floor
  end

  def current_user
    @current_user ||= begin
      if $cgi.key?('username')
        return false if $cgi['username'].empty?

        user = User.find_by_username($cgi['username'])
        return false if user.nil?
        return false if !user.validate($cgi['password'])

        $cookie = CGI::Cookie.new(
          name: 'shintolin',
          value: [user_id.to_s, user.password],
          expires: (Time.now + 1800)
        )
        user
      else
        $cookie = $cgi.cookies['shintolin']
        return nil if $cookie.nil?

        user_id = $cookie[0]

        user = User.new(user_id)
        user = nil if $cookie[1] != user.password
        user
      end
    end
  end

  def xp_field(type)
    case type
    when :herbalist then 'herbal_xp'
    when :crafter then 'craft_xp'
    when :wanderer then 'wander_xp'
    when :warrior then 'warrior_xp'
    end
  end

  def you_or_her(you_id, her_id, you = 'you', link = :link)
    # exactly the same as the function below, but I didn't like
    # having a gender-biased codebase. It's the 21st century.
    you_or_him(you_id, her_id, you, link)
  end

  def you_or_him(you_id, him_id, you = 'you', link = true)
    if you_id.to_i == him_id.to_i
      "<b>#{you}</b>"
    else
      him = User.find(him_id)
      return '' if him.nil?

      link != :no_link ? html_userlink(him_id, him['name']) : him['name']
    end
  end


end