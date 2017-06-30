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
      res[:values] << row[0..col_idx] if row
    end
    res[:session_name] = res[:values][0][col_idx] if res[:values][0]
    if res[:session_name] && res[:session_name].match(/\(\d+\)$/)
      num = res[:session_name].match(/\((\d+)\)$/)[1].to_i
      res[:session_name].sub!(/\(\d+\)$/, '')
      if num && num > 0
        res[:live_attendees] = num
      end
    end
    res
  end
end
