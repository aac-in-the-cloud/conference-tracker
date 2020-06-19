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

  def assert_year
    sessions = ConferenceSession.where(conference_code: self.code)
    if code.match(/\d+$/)
      year = '20' + self.code.match(/\d+$/)[0]
      sessions.each do |session|
        data = session.resources
        time = Time.parse(data['date']) rescue nil
        time = nil if data && data['date'] && data['date'].downcase == 'pre'
        if time
          time = time.change(year: year.to_i)
          data['prior_dates'] ||= []
          data['prior_dates'] << data['date']
          data['date'] = time.strftime('%B %e %Y, %l:%M%P')
          session.resources = data
          session.save
        end
      end
    end
  end

  def self.user_token(string)
    Digest::MD5.hexdigest(string + "::" + ENV['AUTH_SECRET'])
  end
  
  def self.date_string(time, length='default')
    cutoff = (Date.today << 3).to_time
    prior = time < cutoff || time.year < cutoff.year
    tz = ENV['TIME_ZONE'] || 'ET'
    # TODO: time zones
    if time.min == 0
      if length == 'short'
        time.strftime('%l %P ') + tz
      elsif prior || length == 'long'
        time.strftime('%B %e %Y, %l%P ') + tz
      else
        time.strftime('%B %e, %l%P ') + tz
      end
    else
      if length == 'short'
        time.strftime('%l:%M %P ') + tz
      elsif prior || length == 'long'
        time.strftime('%B %e %Y, %l:%M%P ') + tz
      else
        time.strftime('%B %e %Y, %l:%M%P ') + tz
      end
    end
  end

  def year
    "20#{self.code.match(/\d+/)}"
  end
end
