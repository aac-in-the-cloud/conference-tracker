require 'typhoeus'
require 'nokogiri'
require 'json'

class LinksController < ApplicationController
  def show
    response.headers.delete('X-Frame-Options')
  end
  
  def data
    key = ENV['API_KEY']
    body = Rails.cache.fetch("cell/#{ENV['DOC_ID']}/#{params['cell']}") do
      letter_num = params['cell'].match(/[A-Z]+/)[0].ord
      row_num = params['cell'].match(/\d+/)[0].to_i
      start_row = row_num
      end_row = row_num + 3
      start_col = 'A'
      end_col = letter_num.chr
      url = "https://sheets.googleapis.com/v4/spreadsheets/#{ENV['DOC_ID']}/values/#{start_col}#{start_row}:#{end_col}#{end_row}?key=#{key}"
      res = Typhoeus.get(url)
      res.body
    end
    render text: body
  end
  
  def proxy_doc
    response.headers.delete('X-Frame-Options')
    response.headers['Cache-Control'] = 'public'
    text = Rails.cache.fetch("doc/#{params['id']}", expires_in: 30.minutes) do
      url = "https://docs.google.com/document/d/#{params['id']}/pub?embedded=true"
      req = Typhoeus.get(url)
      doc = Nokogiri(req.body)
      doc.css('a').each do |a|
        a['target'] = '_blank'
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
