require 'typhoeus'
require 'nokogiri'

class LinksController < ApplicationController
  def show
  end
  
  def data
    key = ENV['API_KEY']
    
    letter_num = params['cell'].match(/[A-Z]+/)[0].ord
    row_num = params['cell'].match(/\d+/)[0].to_i
    start_row = row_num
    end_row = row_num + 1
    start_col = 'A'
    end_col = letter_num.chr
    url = "https://sheets.googleapis.com/v4/spreadsheets/#{ENV['DOC_ID']}/values/#{start_col}#{start_row}:#{end_col}#{end_row}?key=#{key}"
    res = Typhoeus.get(url)
    render text: res.body
  end
  
  def proxy_doc
    response.headers.delete('X-Frame-Options')
    url = "https://docs.google.com/document/d/#{params['id']}/pub?embedded=true"
    req = Typhoeus.get(url)
    doc = Nokogiri(req.body)
    doc.css('a').each do |a|
      a['target'] = '_blank'
    end
    render text: doc.to_s
  end
end
