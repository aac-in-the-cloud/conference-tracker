require 'typhoeus'
require 'nokogiri'
require 'json'

class LinksController < ApplicationController
  def root
    @conferences = Conference.all.order('code')
  end

  def chat
    redirect_to 'http://aacconference.com/chat'
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
        results = SurveyResult.where(["code LIKE ?", "%#{conference.code}"]).order('id DESC').select{|r| r.json['answer_1'].to_i > 0 }
        json['average_score'] = (results.map{|r| r.json['answer_1'].to_i }.sum.to_f / results.length.to_f).round(2)
        video_id = ((json['youtube_link'] || '').match(/(?:https?:\/\/)?(?:www\.)?youtu(?:be\.com\/watch\?(?:.*?&(?:amp;)?)?v=|\.be\/)([\w \-]+)(?:&(?:amp;)?[\w\?=]*)?/) || [])[1];
        if video_id
          hash = video_data_for(video_id)
          json['video_id'] = video_id
          json['views'] = hash && hash['statistics'] && hash['statistics']['viewCount'].to_i
          json['likes'] = hash && hash['statistics'] && hash['statistics']['likeCount'].to_i
        end
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
    response.headers.delete('X-Frame-Options')
  end

  def video_data_for(video_id)
    key = ENV['API_KEY']
    hash = Rails.cache.fetch("video/#{video_id}", expires_in: 6.hours) do
      url = "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&part=snippet%2CcontentDetails%2Cstatistics%20&key=#{key}"
      req = Typhoeus.get(url)
      json = JSON.parse(req.body)
      json['items'][0]
    end
    hash
  end
  
  def video_data
    hash = video_data_for(params['id'])
    render text: hash.to_json
  end
end
