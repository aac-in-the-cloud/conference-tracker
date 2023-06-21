class ConferenceSession < ApplicationRecord
  before_save :generate_defaults
  include PgSearch

  pg_search_scope :search_by_data, :against => :data, :using => {:tsearch => {:dictionary => 'english', :normalization => 8, :any_word => true}}

  def generate_defaults
    self.conference_code ||= self.code.match(/^\w+\d+(\w+\d+)$/)[1] if self.code
    data = JSON.parse(self.data) rescue nil
    data ||= {}
    if data['session_name']
      data['survey_link'] ||= "#{@@host}/surveys/#{code}"
    end
    self.data = data.to_json
    true
  end

  def video_link
    return nil unless self.code
    data = JSON.parse(self.data) rescue nil
    return nil if data && data['link_disabled']
    "/videos/#{URI.encode(Base64.urlsafe_encode64(Base64.urlsafe_encode64(self.code)))}"
  end
  
  def survey_link
    "/surveys/#{self.code}"
  end

  def token
    raise "code required" unless self.code
    Digest::MD5.hexdigest(Conference.user_token("manage-#{self.code}"))
  end

  def manage_link
    "/conferences/sessions/#{self.code}:#{self.token}"
  end

  def slack_text
    data = JSON.parse(self.data) rescue nil
    data && data['slack_text']
  end

  def year
    "20#{self.conference_code.match(/\d+/)}"
  end

  def self.set_host(host)
    @@host = host
  end

  def self.default_host
    @@host
  end

  def self.conference_name(code)
    yr = code.match(/\d+/)[0]
    return "AAC in the Cloud 20#{yr} Conference"
  end

  def process(params)
    data = JSON.parse(self.data) rescue nil
    data ||= {}

    ['youtube_link', 'hangouts_link'].each do |attr|
      if params[attr]
        data[attr] = params[attr]
      end
    end
    self.data = data.to_json
    self.save
  end

  def update_stats
    data = JSON.parse(self.data) rescue nil
    data ||= {}
    surveys = SurveyResult.where(code: self.code).select{|r| r.json && r.json['answer_1'].to_i > 0 }
    cnt = surveys.length
    avg = (surveys.map{|s| s.json['answer_1'].to_i }.sum.to_f / cnt.to_f).round(2)
    data['average_score'] = avg
    data['total_ratings'] = cnt
    self.data = data.to_json
    self.save
  end

  def zoned_timestamp
    session = self
    Time.find_zone('Eastern Time (US & Canada)').parse(session.resources['timestamp'].sub(/\+00:00/, '')).utc rescue nil
  end
  
  def resources
    return @resources if @resources
    res = JSON.parse(self.data)['resources'] rescue nil
    res = nil if res && !res['session_name']
    @resources = res if res
    res
  end

  def resources=(val)
    data = JSON.parse(self.data) rescue nil
    data ||= {}
    data['resources'] = val
    @resources = val
    self.data = data.to_json
    val
  end

  def self.video_id(video_url)
    return nil unless video_url
    video_url = video_url.sub(/\?feature=share/, '');
    video_url = video_url.sub(/\/live\//, '/watch?v=');
    video_id = (video_url.match(/(?:https?:\/\/)?(?:www\.)?youtu(?:be\.com\/watch\?(?:.*?&(?:amp;)?)?v=|\.be\/)([\w \-]+)(?:&(?:amp;)?[\w\?=]*)?/) || [])[1];
  end

  def self.video_data_for(video_id, session, include_live=false)
    # liveStreamingDetails.concurrentViewers, liveStreamingDetails.actualEndTime
    key = ENV['API_KEY']
    fetch_key = "video/stats/#{video_id}"
    exp = 6.hours
    if include_live
      fetch_key = "video/stats/fast/#{video_id}"
      exp = 1.5.minutes
    else
      ts = session && session.zoned_timestamp
      if ts && ts > 3.hours.ago
        exp = 10.minutes
      elsif ts && ts > 12.hours.ago
        exp = 30.minutes
      end
    end
    hash = Rails.cache.fetch(fetch_key)
    hash['cached'] = true if hash
    hash = nil if include_live
    if !hash
      hash = Rails.cache.fetch(fetch_key, expires_in: exp) do
        url = "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&part=snippet%2CcontentDetails%2Cstatistics%2CliveStreamingDetails%20&key=#{key}"
        req = Typhoeus.get(url)
        json = JSON.parse(req.body)
        res = json['items'][0]
        if session && res
          json = JSON.parse(session.data)
          hours = json['resources']['hours'].to_f
          hours = 1.0 if hours == 0.0
          json['views'] = res['statistics'] && res['statistics']['viewCount'].to_i
          if res['liveStreamingDetails'] && !res['liveStreamingDetails']['actualEndTime']
            json['max_live'] = [json['max_live'] || 0, res['liveStreamingDetails']['concurrentViewers'].to_i].max
          end
          session_mostly_done = false
          ts = session.zoned_timestamp
          if hours > 0.1
            # 0.1-hour sessions should never get survey links,
            # so don't ever bother marking a live attendees number
            mostly_watched_cutoff = (hours * 40).minutes.ago
            if ts && ts != 'pre' && ts < mostly_watched_cutoff
              session_mostly_done = true
            end
            if json['max_live'] && (res['liveStreamingDetails']['actualEndTime'] || session_mostly_done)
              json['resources']['live_attendees'] = [json['max_live'], json['resources']['live_attendees'] || 0, 1].max
            end
          end
          session.data = json.to_json
          session.save
        end
        res 
      end
    end
    hash
  end  
end
