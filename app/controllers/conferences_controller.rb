class ConferencesController < ApplicationController
  def show
    response.headers.except! 'X-Frame-Options'
    sessions = ConferenceSession.where(:conference_code => params['id'])
    conference = Conference.find_by(code: params['id'])
    if !conference
      render text: "Invalid Conference"
      return
    elsif sessions.count == 0
      render text: "No Sessions"
      return
    end
    @conference = {
      name: conference.name,
      year: "20#{params['id'].match(/\d+/)[0]}",
      tracks: [],
      days: []
    }
    sessions = sessions.select{|s| s.resources }
    days = sessions.group_by{|s| s.resources['timestamp'][0, 10] }.to_a.sort_by(&:first)
    max_tracks = sessions.group_by{|s| s.resources['timestamp']}.to_a.map(&:last).map(&:length).max

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
end
