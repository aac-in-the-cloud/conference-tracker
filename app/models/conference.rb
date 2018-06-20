class Conference < ApplicationRecord
  before_save :generate_defaults

  def generate_defaults
    if !self.code
      yr = Time.now.year.to_s[2, 2]
      confs = Conference.where("code LIKE '%#{yr}'").order('code')
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

  def year
    "20#{self.code.match(/\d+/)}"
  end
end
