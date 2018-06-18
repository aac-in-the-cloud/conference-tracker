class ConferenceSession < ApplicationRecord
  before_save :generate_defaults

  def generate_defaults
#    self.conference_code ||= self.code.match(/^\w+\d+(\w+\d+)$/)[1] if self.code
    data = JSON.parse(self.data) rescue nil
    data ||= {}
    if data['session_name']
      data['survey_link'] ||= "#{@@host}/surveys/#{code}"
    end
    true
  end

  def video_link
    return nil unless self.code
    "/videos/#{Base64.encode64(Base64.encode64(self.code))}"
  end
  
  def survey_link
    "/surveys/#{self.code}"
  end

  def self.set_host(host)
    @@host = host
  end

  def self.default_host
    @@host
  end

  def process(params)
    data = JSON.parse(self.data) rescue nil
    data ||= {}

    ['youtube_link', 'hangouts_link'].each do |attr|
      if params[attr]
        data[attr] = params[attr]
      end
    end
    self.data = data
    self.save
  end

  def resources
    JSON.parse(self.data)['resources'] rescue nil
  end

  def resources=(val)
    data = JSON.parse(self.data) rescue nil
    data ||= {}
    data['resources'] = val
    self.data = data
    val
  end
end
