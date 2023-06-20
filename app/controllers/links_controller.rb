require 'typhoeus'
require 'nokogiri'
require 'json'

class LinksController < ApplicationController
  def root
    @conferences = Conference.all.order('code')
  end

  def chat
    redirect_to 'http://www.aacconference.com/chat.html'
  end

  def show
    cell, token = params['cell'].split(/:/)
    session = ConferenceSession.find_by_code(cell)
    if session.token[0, 5] != token
      render text: "Invalid Session"
      return
    end
    params['cell'] = cell
    response.headers.delete('X-Frame-Options')
    @session_id = params['cell']
    @session_id += "A17" unless @session_id.match(/^\w+\d+\w+\d+$/)
    @conf_id = @session_id.match(/\w+\d+(\w+\d+)/)[1]
    @year = "20#{@conf_id.match(/\d+/)[0]}"
  end
  
  def data
    json = SurveyResult.session_data(params['cell'])
    time = Time.parse(json['date']) rescue nil
    if time
      json['timestamp'] = time.to_i
      json['date'] = Conference.date_string(time)
    end
    if @authenticated
      session = ConferenceSession.find_by(code: json['code'])
      conference = Conference.find_by(code: session.conference_code)
      json['manage_link'] = session.manage_link
      if params['stats']
        json['average_score'] = session.resources['average_score']
        if !json['average_score']
          results = SurveyResult.where(code: session.code) #["code LIKE ?", "%#{conference.code}"]).order('id DESC').select{|r| r.json['answer_1'].to_i > 0 }
          json['average_score'] = (results.map{|r| r.json['answer_1'].to_i }.sum.to_f / results.length.to_f).round(2) if results.length > 0
        end
        video_id = ((json['youtube_link'] || '').match(/(?:https?:\/\/)?(?:www\.)?youtu(?:be\.com\/watch\?(?:.*?&(?:amp;)?)?v=|\.be\/)([\w \-]+)(?:&(?:amp;)?[\w\?=]*)?/) || [])[1];
        if video_id
          hash = video_data_for(video_id, session, true)
          json['video_id'] = video_id
          json['cached_video_data'] = !!hash['cached']
          json['views'] = hash && hash['statistics'] && hash['statistics']['viewCount'].to_i
          json['likes'] = hash && hash['statistics'] && hash['statistics']['likeCount'].to_i
        end
      end
    else
      session = ConferenceSession.find_by(code: json['code'])
      ts = session && session.zoned_timestamp
      video_url = json['youtube_link'] || ''
      video_url.sub!(/\?feature=share/, '');
      video_url.sub!(/\/live\//, '/watch?v=');
      video_id = (video_url.match(/(?:https?:\/\/)?(?:www\.)?youtu(?:be\.com\/watch\?(?:.*?&(?:amp;)?)?v=|\.be\/)([\w \-]+)(?:&(?:amp;)?[\w\?=]*)?/) || [])[1];
      if ts && ts != 'pre' && ts > 120.minutes.ago && video_id
        video_data_for(video_id, session, true)
      end
    end
    render text: json.to_json
  end

  def proxy_doc
    response.headers.delete('X-Frame-Options')
    response.headers['Cache-Control'] = 'public'
    change_target = params['no_blank'] != '1'
    text = Rails.cache.fetch("doc/#{params['id']}/#{change_target}", expires_in: 30.minutes) do
      url = "https://docs.google.com/document/d/#{params['id']}/pub?embedded=true"
      req = Typhoeus.get(url)
      doc = Nokogiri(req.body)
      if change_target
        doc.css('a').each do |a|
          a['target'] = '_blank'
        end
      end
      doc.to_s
    end
    render text: text
  end
  
  def video
    @session_id = Base64.decode64(Base64.decode64(params['id']))
    @session_id += "A17" unless @session_id.match(/^\w+\d+\w+\d+$/)
    @conf_id = @session_id.match(/\w+\d+(\w+\d+)/)[1]
    @year = "20#{@conf_id.match(/\d+/)[0]}"
    session = ConferenceSession.find_by(code: @session_id)
    if session && session.resources
      conf = Conference.find_by(code: session.conference_code)
      name = session.resources['session_name']
      name = "#{conf.name} - #{name}" if conf
      image = "https://presenters.aacconference.com/logo-2017.png"
      image = "#{request.protocol}#{request.host_with_port}/logo-#{conf.year}.png" if conf
      if session.resources['youtube_link']
        video_id = ((session.resources['youtube_link'] || '').match(/(?:https?:\/\/)?(?:www\.)?youtu(?:be\.com\/watch\?(?:.*?&(?:amp;)?)?v=|\.be\/)([\w \-]+)(?:&(?:amp;)?[\w\?=]*)?/) || [])[1];
        if video_id
          data = video_data_for(video_id, session)
          if data && data['statistics'] && data['statistics']['viewCount'].to_i > 0
            image = "https://img.youtube.com/vi/#{video_id}/0.jpg"
          end
        end
      end
      @meta_record = OpenStruct.new({
        title: session.resources['session_name'],
        summary: session.resources['description'],
        image: image,
        link: request.original_url,
        created: session.created_at.iso8601,
        updated: session.updated_at.iso8601
      })
    end
    response.headers.delete('X-Frame-Options')
  end


  def video_data_for(video_id, session, include_live=false)
    # liveStreamingDetails.concurrentViewers, liveStreamingDetails.actualEndTime
    key = ENV['API_KEY']
    fetch_key = "video/stats/#{video_id}"
    exp = 12.hours
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

  def video_data
    hash = video_data_for(params['id'], nil)
    render text: hash.to_json
  end
end
