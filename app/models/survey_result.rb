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
end
