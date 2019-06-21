class Conference < ApplicationRecord
  before_save :generate_defaults

  def generate_defaults
    if !self.code
      yr = Time.now.year.to_s[2, 2]
      confs = Conference.where(["code LIKE ?", "%#{yr}"]).order('code')
      letter = 'A'
      if confs.count > 0
        letter = (confs.last.code[0].ord + 1).chr
      end
      self.code = "#{letter}#{yr}"
    end
  end

  def self.user_token(string)
    Digest::MD5.hexdigest(string + "::" + ENV['AUTH_SECRET'])
  end
  
  def self.date_string(time, length='default', time_zone=nil)
    cutoff = (Date.today << 3).to_time
    prior = time < cutoff || time.year < cutoff.year
    # TODO: time zones
    if time.min == 0
      if length == 'short'
        time.strftime('%l %P ET')
      elsif prior || length == 'long'
        time.strftime('%B %e %Y, %l%P ET')
      else
        time.strftime('%B %e, %l%P ET')
      end
    else
      if length == 'short'
        time.strftime('%l:%M %P ET')
      elsif prior || length == 'long'
        time.strftime('%B %e %Y, %l:%M%P ET')
      else
        time.strftime('%B %e %Y, %l:%M%P ET')
      end
    end
  end

  def year
    "20#{self.code.match(/\d+/)}"
  end
end
