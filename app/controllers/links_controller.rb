require 'typhoeus'
require 'nokogiri'
require 'json'

class LinksController < ApplicationController
  def root
    @conferences = Conference.all.order('code').reverse
    @week = FeedWeek.current_for('all')
    @session_records = (@week && @week.session_records) || []
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

  def feed
    @weeks = FeedWeek.where(['year >= ?', Time.now.year]).order('CONCAT(year, RIGHT(CONCAT(\'00\',week), 2)) DESC').limit(15)
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
        video_id = ConferenceSession.video_id(json['youtube_link'])
        if video_id
          hash = ConferenceSession.video_data_for(video_id, session, true)
          json['video_id'] = video_id
          json['cached_video_data'] = !!hash['cached']
          json['views'] = hash && hash['statistics'] && hash['statistics']['viewCount'].to_i
          json['likes'] = hash && hash['statistics'] && hash['statistics']['likeCount'].to_i
        end
      end
    else
      session = ConferenceSession.find_by(code: json['code'])
      ts = session && session.zoned_timestamp
      video_id = ConferenceSession.video_id(json['youtube_link'])
      if ts && ts != 'pre' && ts > 120.minutes.ago && video_id
        ConferenceSession.video_data_for(video_id, session, true)
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
        video_id = ConferenceSession.video_id(session.resources['youtube_link'])
        if video_id
          data = ConferenceSession.video_data_for(video_id, session)
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

  def video_data
    hash = ConferenceSession.video_data_for(params['id'], nil)
    render text: hash.to_json
  end
end
