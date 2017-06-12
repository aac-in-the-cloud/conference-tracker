require 'typhoeus'

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
end
