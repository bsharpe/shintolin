class Array
  def sum
    self.inject(0){ |sum, x| sum + x }
  end
end

module Math
  def self.binomial(trials, probability)
    successes = 0
    trials.times do
      successes += 1 if rand < probability
    end
    successes
  end
end

class Integer
  def to_1
    self.zero? ? 0 : self < 0 ? -1 : 1
  end
end

class CGI
  def str_params
    $cgi.params
  end
end

class String
  def capitalize
    split.map { |x| x[0].upcase + x[1..-1] }.join(' ')
  end
end

class Time
  def self.str_to_time(str)
    Time.parse(str.to_s).localtime
  end

  def ago
    secs = (Time.now.to_i - to_i)
    if secs < 5
      'just now'
    elsif secs < 60
      "#{secs} seconds ago"
    elsif secs < 3600
      mins = secs / 60
      "#{mins} minutes ago"
    elsif secs < 3600 * 24
      hours = secs / 3600
      "#{hours} hours ago"
    else
      days = secs / (3600 * 24)
      "#{days} days ago"
    end
  end
end
