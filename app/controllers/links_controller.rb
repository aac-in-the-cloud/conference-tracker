require 'typhoeus'
require 'nokogiri'
require 'json'

class LinksController < ApplicationController
  def show
    response.headers.delete('X-Frame-Options')
  end
  
  def data
    key = ENV['API_KEY']
    letter_num = params['cell'].match(/[A-Z]+/)[0].ord
    row_num = params['cell'].match(/\d+/)[0].to_i
    start_row = row_num
    end_row = row_num + 3
    start_col = 'A'
    end_col = letter_num.chr
    
    body = Rails.cache.fetch("cell/#{ENV['DOC_ID']}", expires_in: 60.seconds) do
      url = "https://sheets.googleapis.com/v4/spreadsheets/#{ENV['DOC_ID']}/values/A1:D100?key=#{key}"
#      res = Typhoeus.get(url)
#      res.body
      "{}"
    end
    json = JSON.parse(body)
    res = {values: []}
    if !json['values']
      render text: body
      return
    end
    
    (start_row..end_row).to_a.each do |idx|
      row = json['values'][idx - 1]
      res[:values] << row
    end
    
    render text: ers.to_json
  end
  
  def proxy_doc
    response.headers.delete('X-Frame-Options')
    response.headers['Cache-Control'] = 'public'
    change_target = params['noblank'] != '1'
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
    response.headers.delete('X-Frame-Options')
  end
  
  def video_data
    key = ENV['API_KEY']
    hash = Rails.cache.fetch("video/#{params['id']}", expires_in: 30.minutes) do
      url = "https://www.googleapis.com/youtube/v3/videos?id=#{params['id']}&part=snippet%2CcontentDetails%2Cstatistics%20&key=#{key}"
      req = Typhoeus.get(url)
      json = JSON.parse(req.body)
      json['items'][0]
    end
    render text: hash.to_json
  end
end
