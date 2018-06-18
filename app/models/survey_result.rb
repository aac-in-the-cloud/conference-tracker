class SurveyResult < ApplicationRecord
  def self.process(params)
    if params['email'] && params['code']
      hash = Digest::MD5.hexdigest(params['email'].downcase)
      code = params['code']
      record = SurveyResult.find_or_create_by(email_hash: hash, code: code)
      json = {
        name: params['name'],
        email: params['email'],
        code: params['code'],
      }
      10.times do |idx|
        key = "answer_#{idx}"
        if params[key]
          json[key] = params[key]
        end
      end
      record.data = json.to_json
      record.save
      record
    else
      false
    end
  end
  
  def json
    @json ||= JSON.parse(self.data) rescue nil
  end
  
  def self.session_data(cell)
    key = ENV['API_KEY']
    code = cell
    code += "A17" unless code.match(/\w+\d+\w+\d+/)
    session = ConferenceSession.find_or_create_by(code: code)
    if !session.resources || (session.updated_at < 1.hour.ago && !session.resources['live_attendees'])
      letter_num = cell.match(/[A-Z]+/)[0].ord
      col_idx = letter_num - 'A'.ord
      row_num = cell.match(/\d+/)[0].to_i
      start_row = row_num
      end_row = row_num + 3
      start_col = 'A'
      end_col = letter_num.chr
      
      body = Rails.cache.fetch("cell/#{ENV['DOC_ID']}", expires_in: 30.minutes) do
        url = "https://sheets.googleapis.com/v4/spreadsheets/#{ENV['DOC_ID']}/values/A1:D100?key=#{key}"
        res = Typhoeus.get(url)
        res.body
      end
      json = JSON.parse(body)

      res = {values: []}
      if !json['values']
        return json
      end
      
      (start_row..end_row).to_a.each do |idx|
        row = json['values'][idx - 1]
        if row
          ref = []
          ref << row[0]
          ref << row[col_idx]
          res[:values] << ref
        end
      end
      res[:date] = res[:values][0][0] if res[:values][0][0]
      10.times do |i|
        yr = (2017 + i).to_s
        res[:date] = res[:date].sub(/,/, "#{yr},") if res[:date] && code.match(/#{yr[2, 2]}$/) && !res[:date].match(/#{yr}/)
      end
      res[:timestamp] = Time.parse(res[:date]).iso8601 if res[:date]
      res[:session_name] = res[:values][0][1] if res[:values][0]
      res[:survey_link] = res[:values][2][1] if res[:values][2]
      res[:youtube_link] = res[:values][3][1] if res[:values][3]

      if res[:session_name] && res[:session_name].match(/\(\d+\)$/)
        num = res[:session_name].match(/\((\d+)\)$/)[1].to_i
        res[:session_name].sub!(/\(\d+\)$/, '')
        if num && num > 0
          res[:live_attendees] = num
        end
      end
      session.resources = res
      session.save!
    end
    res = session.resources || {}
    res['survey_link'] = session.survey_link
    res['video_link'] = session.video_link
    res
  end
end
