class Conference < ApplicationRecord
  def self.user_token(string)
    Digest::MD5.hexdigest(string + "::" + ENV['AUTH_SECRET'])
  end
end
