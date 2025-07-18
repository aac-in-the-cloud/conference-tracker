require 'ostruct'
class ConferencesController < ApplicationController
  def create
    if !@authenticated
      render json: {error: 'Not Authorized'}, status: 400
      return
    end
    conference = Conference.new
    if params['code']
      conference = Conference.find_by(code: params['code'])
      if !conference
        render json: {error: 'Not Found'}, status: 400
        return
      end
    end
    data = JSON.parse(conference.data) rescue nil
    data ||= {}
    conference.name = params['name'] if !params['name'].blank?
    data['theme'] = params['theme'] if !params['theme'].blank?
    data['pre_note'] = params['pre_note'] if !params['pre_note'].blank?
    data['closed'] = params['closed'] if params['closed'] != nil
    data['filled'] = params['filled'] if !params['filled'] != nil
    if params['track_map']
      hash = {}
      params['track_map'].split(/\n/).each do |line|
        track, str = line.strip.split(/\=/, 2)
        hash[track] = str
      end
      data['track_subtitles'] = hash
    end
    conference.data = data.to_json
    conference.save
    Rails.cache.delete("conference/#{conference.code}")
    render json: {code: conference.code}
  end

  def search
    response.headers.except! 'X-Frame-Options'

    sessions = ConferenceSession.all
    if params['q']
      sessions = ConferenceSession.search_by_data(params['q'])
    end
    if params['conference_code'] && params['conference_code'] != 'all' && !params['conference_code'].blank?
      sessions = sessions.where(conference_code: params['conference_code']) 
    end
    if params['sort']
      list = sessions.all.map do |s|
        json = JSON.parse(s.data)
        hash = {
          id: s.id,
          score: json['average_score'] || 0,
          ratings: json['total_ratings'] || 0,
          views: json['views'],
          live: (json['resources'] || {})['live_attendees'] || 0,
          ref: s
        }
        s.instance_variable_set('@ratings', hash)
        hash
      end
      sort_by = params['sort']
      if sort_by == 'rating'
        @sort = "Highest-Rated"
        list = list.select{|s| s[:ratings] > 25 }
        sessions = list.sort_by{|s| s[:score] }.reverse.map{|s| s[:ref] }
      elsif sort_by == 'most_rated'
        @sort = "Most-Rated"
        sessions = list.sort_by{|s| s[:ratings] }.reverse.map{|s| s[:ref] }
      elsif sort_by == 'views'
        @sort = "Most-Watched"
        sessions = list.sort_by{|s| s[:views] || s[:ratings] }.reverse.map{|s| s[:ref] }
      elsif sort_by == 'attendees'
        @sort = "Most-Attended"
        sessions = list.sort_by{|s| s[:live] }.reverse.map{|s| s[:ref] }
      end
      sessions = sessions[0, 50].select{|s| s.resources }
    else
      sessions = sessions.limit(25)
    end
    @conferences = {}
    @conference_list = []
    Conference.all.order('id').each do |conf|
      conference_json = JSON.parse(conf.data) rescue nil
      conference_json ||= {}
      @conference_list << {
        :name => conf.name,
        :code => conf.code
      }
      @conferences[conf.code] = {
        :name => conf.name,
        :theme => conference_json['theme'],
        :pre_note => conference_json['pre_note'],
        :code => conf.code,
        :closed => !!conference_json['closed'],
        :year => conf.year
      }
    end
    @sessions = sessions
  end

  def show
    response.headers.except! 'X-Frame-Options'
    conference = Conference.find_by(code: params['id'])
    if !conference
      render plain: "Invalid Conference"
      return
    end
    @conference = Rails.cache.fetch("conference/#{params['id']}", expires_in: 15.minutes) do
      conference_json = JSON.parse(conference.data) rescue nil
      conference_json ||= {}
      sessions = ConferenceSession.where(:conference_code => params['id'])
      conference = {
        name: conference.name,
        code: conference.code,
        created: conference.created_at.iso8601,
        updated: conference.updated_at.iso8601,
        year: "20#{params['id'].match(/\d+/)[0]}",
        theme: conference_json['theme'],
        pre_note: conference_json['pre_note'],
        closed: !!conference_json['closed'],
        filled: !!(conference_json['closed'] || conference_json['filled']),
        tracks: [],
        days: []
      }
      conference[:track_map] = (conference_json['track_subtitles'] || {}).map{|t, str| "#{t}=#{str}"}.join("\n")
      all_tracks = []
      sessions = sessions.select{|s| s.resources }
      sessions.each do |session|
        if session.resources['track'] && !all_tracks.include?(session.resources['track'])
          if session.resources['timestamp'] != 'pre'
            all_tracks.push(session.resources['track'])
          end
        end
      end
      days = sessions.group_by{|s| s.resources['timestamp'] == 'pre' ? '_pre' : s.resources['timestamp'][0, 10] }.to_a.sort_by(&:first)
      max_tracks = sessions.select{|s| s.resources['timestamp'] != 'pre' }.group_by{|s| s.resources['timestamp']}.to_a.map(&:last).map(&:length).max || 1
      while max_tracks > all_tracks.length
        i = 1
        while all_tracks.include?(i.to_s)
          i += 1
        end
        all_tracks.push(i.to_s)
      end
      other_tracks = sessions.map{|s| s.resources['track'] }.compact.uniq
      all_tracks += other_tracks
      all_tracks = all_tracks.uniq.sort
      days = days.sort_by{|arr| arr[0] == '_pre' ? '0000-00-00' : arr[0] }
      days.each do |day_id, list|
        day = {
          day_id: day_id,
          name: day_id == '_pre' ? 'Pre-Conference Sessions' : Date.parse(day_id).strftime('%B %e, %Y'),
          time_slots: []
        }
        time_slots = list.group_by{|s| s.resources['timestamp']}.to_a.sort_by(&:first)
        if day_id == '_pre'
          track_chunks = list.group_by{|s| s.resources['track'] || 'any' }
          tracks_left = track_chunks.map{|t, l| l.length }.max
          day[:pre_note] = conference_json['pre_note']
          time_slots = {}
          slot_num = 0
          any_chunk = (track_chunks.detect{|t, l| t == 'any' } || [])[1] || []
          while tracks_left > 0
            chunk = []
            all_tracks.each do |id|
              track_chunk = (track_chunks.detect{|t, l| t == id } || [])[1] || []
              chunk.push(track_chunk.shift || any_chunk.shift) 
            end
            tracks_left = track_chunks.map{|t, l| l.length }.max
            time_slots["pre_#{slot_num}"] = chunk.compact
            slot_num += 1
          end
          # cnt = 0
          # list.each_slice(max_tracks) do |slice|
          #   time_slots["pre_#{cnt}"] = slice
          #   cnt += 1
          # end
        end
        time_slots.each do |timestamp, list|
          time = 'pre'
          name = ""
          if !timestamp.match(/pre/)
            time = Time.parse(timestamp)
            name = Conference.date_string(time, 'short')
          end
          slot = {
            name: name,
            tracks: [],
            special: (time != 'pre' && max_tracks > 1 && list.length == 1)
          }
          # if day_id != '_pre'
          #   max_tracks = [max_tracks, list.length].max
          # end
          tracks_left = list.sort_by(&:code)
          all_tracks.each do |track_str|
            session = tracks_left.detect{|s| s.resources['track'] == track_str }
            session ||= tracks_left.detect{|s| !s.resources['track'] }
            session ||= tracks_left[0]
            if session
              tracks_left -= [session]
              track = {
                name: session.resources['session_name'],
                description: session.resources['description'],
                code: session.code,
                link: session.video_link,
                manage: session.manage_link,
                slack: session.slack_text
              }
              slot[:tracks] << track
            end
          end
          day[:time_slots] << slot
        end
        conference[:days] << day
      end
      all_tracks.each do |track|
        name = track
        name = "Track #{track}" if track.to_s.length <= 2
        subname = (conference_json['track_subtitles'] || {})[track]
        conference[:tracks] << {name: name, subtitle: subname}
      end
      conference
    end
    # <!-- expects @meta_record.(title, summary, large_image, image, link, created, updated) -->
    # <img style='float: left; max-height: 100px; max-width: 150px; margin-bottom: 5px; border-radius: 5px;' src='/logo-<%= @conference[:year] %>.png' onerror="this.src='/logo.png';"/>
    @conference = @conference.with_indifferent_access
    @meta_record = OpenStruct.new({
      title: @conference[:name],
      summary: "Here you'll find a listing of all sessions for the #{@conference[:name]}!",
      image: "#{request.protocol}#{request.host_with_port}/logo-#{@conference[:year]}.png",
      link: request.original_url,
      created: @conference[:created],
      updated: @conference[:updated]
    })
  end

  def manage_session
    code, token = params['id'].split(/:/)
    @session_type = :zoom
    @session = ConferenceSession.find_by(code: code)
    if @session.token != token
      render plain: "Invalid Session"
      return
    end
    @token = token;
  end

  def add_session # or update_session
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
    if !session.id && !@authenticated
      render json: {error: 'not authorized to create new'}, status: 400
      return
    end
    data = session.resources
    data ||= {}
    data.delete('resources')
    data['hangouts_link'] = params['hangout'] if !params['hangout'].blank?

    if @authenticated
      data['date'] = params['time'] if !params['time'].blank?
      data['session_name'] = params['name'] if !params['name'].blank?
      data['conference_name'] = conference.name
      data['description'] = params['description'] if !params['description'].blank?
      data['hours'] = params['hours'].to_f if !params['hours'].blank?
      data['track'] = params['track'] if !params['track'].blank?
      data['youtube_link'] = params['url'] if !params['url'].blank?
      data['youtube_link'] = nil if params['url'] == ''
      data['live_attendees'] = params['live_attendees'].to_i if (params['live_attendees'] || '').to_i > 0
      data['slides_link'] = params['slides'] if params['slides'] != nil
    end

    date = data['date']
    code = conference.code
    10.times do |i|
      yr = (2017 + i).to_s
      date = date.sub(/,/, " #{yr},") if date && code.match(/#{yr[2, 2]}$/) && !date.match(/#{yr}/)
    end
    if data['date'] == 'PRE'
      data['timestamp'] = 'pre'
    else
      data['timestamp'] = Time.parse(data['date']).iso8601
    end
    if !session.code
      existing = ConferenceSession.where(conference_code: conference.code).select{|s| s.resources && s.resources['timestamp'] == data['timestamp'] }
      max = ConferenceSession.where(conference_code: conference.code).map{|c| c.code.match(/^\w(\d+)/)[1].to_i}.max || 0
      total = ConferenceSession.where(conference_code: conference.code).count
      session.code = ('A'.ord + existing.length).chr + ([max, total].max + 1).to_s + conference.code
      session.conference_code = conference.code
    end
    session.resources = data
    if data['live_attendees']
      json = JSON.parse(session.data)
      json.delete('max_live')
      session.data = json.to_json
    end
    if params['link_disabled'] != nil || params['link_pre_live'] != nil
      json = JSON.parse(session.data)
      json['link_disabled'] = !!params['link_disabled'] if params['link_disabled'] != nil
      json['link_pre_live'] = !!params['link_pre_live'] if params['link_pre_live'] != nil
      session.data = json.to_json
    end
    session.save
    Rails.cache.delete("conference/#{session.conference_code}")

    render json: {code: session.code}
  end

  def links
    @conference = Conference.find_by(code: params['id'])
    if !@conference
      render plain: "Invalid Conference"
      return
    end
    verifier = Digest::MD5.hexdigest(Conference.user_token(params['codes']))[0, 10]
    if params['verifier'] == 'admincough' && @authenticated
      codes, moderator = params['codes'].split(/:/)
      moderator = Base64.urlsafe_encode64(moderator || '')
      codes = codes + ":" + moderator
      verifier = Digest::MD5.hexdigest(Conference.user_token(codes))[0, 10]
      redirect_to action: 'links', id: params['id'], codes: codes, verifier: verifier
      return
    elsif params['verifier'] != verifier
      render plain: "Invalid Verifier"
      return
    end
    codes, moderator = params['codes'].split(/:/)
    moderator = Base64.decode64(moderator) rescue nil
    moderator = "Moderator" if moderator.blank?
    @moderator = moderator
    codes = codes.split(/,/)
    @sessions = ConferenceSession.where(code: codes, conference_code: @conference.code).sort_by{|s| [s.resources['timestamp'], s.code] }
  end

  def login; end

  def logout
    cookies.delete :auth
    redirect_to '/'
  end
end
