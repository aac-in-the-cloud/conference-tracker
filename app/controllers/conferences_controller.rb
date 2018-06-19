class ConferencesController < ApplicationController
  def show
    response.headers.except! 'X-Frame-Options'
    sessions = ConferenceSession.where(:conference_code => params['id'])
    conference = Conference.find_by(code: params['id'])
    if !conference
      render text: "Invalid Conference"
      return
    end
    conference_json = JSON.parse(conference.data) rescue nil
    conference_json ||= {}
    @conference = {
      name: conference.name,
      code: conference.code,
      year: "20#{params['id'].match(/\d+/)[0]}",
      closed: !!conference_json['closed'],
      tracks: [],
      days: []
    }
    sessions = sessions.select{|s| s.resources }
    days = sessions.group_by{|s| s.resources['timestamp'][0, 10] }.to_a.sort_by(&:first)
    max_tracks = sessions.group_by{|s| s.resources['timestamp']}.to_a.map(&:last).map(&:length).max || 0

    days.each do |day, list|
      day = {
        name: Date.parse(day).strftime('%B %e, %Y'),
        time_slots: []
      }
      time_slots = list.group_by{|s| s.resources['timestamp']}.to_a.sort_by(&:first)
      time_slots.each do |timestamp, list|
        time = Time.parse(timestamp)
        name = time.min == 0 ? time.strftime('%l %P ET') : time.strftime('%l:%M %P ET')
        slot = {
          name: name,
          tracks: [],
          special: (max_tracks > 1 && list.length == 1)
        }
        max_tracks = [max_tracks, list.length].max
        list.sort_by(&:code).each do |session|
          track = {
            name: session.resources['session_name'],
            link: session.video_link,
            slack: session.slack_text
          }
          slot[:tracks] << track
        end
        day[:time_slots] << slot
      end
      @conference[:days] << day
    end
    max_tracks.times do |i|
      @conference[:tracks] << "Track #{i + 1}"
    end
  end

  def manage_session
    code, token = params['id'].split(/:/)
    @session = ConferenceSession.find_by(code: code)
    if @session.token != token
      render text: "Invalid Session"
      return
    end
    @token = token;
  end

  def add_session
    if !@authenticated
      render json: {error: 'not authenticated'}, status: 400
      return
    end
    conference = Conference.find_by(code: params['conference_code'])
    if !conference
      render json: {error: 'no conference found'}, status: 400
      return
    end
    conference_json = JSON.parse(conference.data) rescue nil
    conference_json ||= {}
    if conference_json['closed']
      render json: {error: 'conference closed'}, status: 400
      return
    end
    session = ConferenceSession.new
    if params['code']
      session = ConferenceSession.find_by(code: params['code'])
      if !session
        render json: {error: 'session not found'}, status: 400
        return
      elsif session.token != params['token']
        render json: {error: 'not authorized'}, status: 400
        return
      end
    end
    data = JSON.parse(session.data) rescue nil
    data ||= {}
    data['date'] = params['time'] if !params['time'].blank?
    data['session_name'] = params['name'] if !params['name'].blank?
    data['description'] = params['description'] if !params['description'].blank?
    data['youtube_link'] = params['url'] if !params['url'].blank?
    data['hangouts_link'] = params['hangout'] if !params['hangout'].blank?
    data['live_attendees'] = params['live_attendees'].to_i if (params['live_attendees'] || '').to_i > 0

    date = data['date']
    code = conference.code
    10.times do |i|
      yr = (2017 + i).to_s
      date = date.sub(/,/, " #{yr},") if date && code.match(/#{yr[2, 2]}$/) && !date.match(/#{yr}/)
    end
    data['timestamp'] = Time.parse(data['date']).iso8601

    if !session.code
      existing = ConferenceSession.where(conference_code: conference.code).select{|s| s.resources && s.resources['timestamp'] == data[:timestamp] }
      total = ConferenceSession.where(conference_code: conference.code).count
      session.code = ('A'.ord + existing.length).chr + (total + 1).to_s + conference.code
      session.conference_code = conference.code
    end
    session.resources = data
    session.save

    render json: {code: session.code}
  end

  def login; end

  def logout
    cookies.delete :auth
    redirect_to '/'
  end
end
