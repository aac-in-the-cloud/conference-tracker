class SurveysController < ApplicationController
  def index
    response.headers.delete('X-Frame-Options')
  end
  
  def show
    response.headers.delete('X-Frame-Options')
    @doc_id = params['id']
    @year = "20#{@doc_id.match(/\d+$/)[0]}" rescue nil
    @year ||= '2017'
    @conf_id = @doc_id.match(/\w+\d+(\w+\d+)/)[1]
  end
  
  def create
    req = SurveyResult.process(params)
    render json: req.data || {}.to_json
  end

  def emails
    if @authenticated
      id = params['id']
      @results = SurveyResult.where(code: id).order('id DESC').select{|r| r.json['answer_1'].to_i > 0 }
      data = @results.map do |sr|
        sr.json['email']
      end.uniq.join("\n")
      send_data data, :type => 'text/csv', :disposition => 'attachment; filename=emails.csv'            
    else
      render text: "Not authorized"
    end
  end
  
  def results
    if params['id'] && params['code'] == 'admincough' && @authenticated
      id = Base64.urlsafe_encode64(Base64.urlsafe_encode64(params['id']))
      code = Digest::MD5.hexdigest(Conference.user_token(id))[0, 10]
      redirect_to action: 'results', id: id, code: code
      return
    end
    id = Base64.decode64(Base64.decode64(params['id']))

    @doc_id = id
    @year = "20#{@doc_id.match(/\d+$/)[0]}" rescue nil
    @year ||= '2017'
    @error = true unless params['code'] == Digest::MD5.hexdigest(Conference.user_token(params['id']))[0, 10]
    if id.match(/all/)
      all, code = id.split(/:/)
      @conference = Conference.find_by(code: code)
      if !@conference
        render text: "Conference not found"
        return
      end
      @data = {}
      @results = SurveyResult.where(["code LIKE ?", "%#{@conference.code}"]).order('id DESC').select{|r| r.json['answer_1'].to_i > 0 }
      @shown_results = @results.select{|r| r.json['answer_1'].to_i > 0 && r.json['answer_3'] && r.json['answer_3'].length > 0 }
      @counts = {}
      @results.group_by(&:email_hash).each{|hash, list| @counts[list.length] ||= 0; @counts[list.length] += 1 }
      @counts = @counts.to_a.sort_by(&:first).reverse
    else
      @data = SurveyResult.session_data(id)
      @results = SurveyResult.where(code: id).order('id DESC').select{|r| r.json['answer_1'].to_i > 0 }
      @shown_results = @results
    end
  end

  def stats
    json = []
    days = params['days'].to_i
    days = 60 if !days || days == 0

    start_date = (Date.today - days)
    end_date = Date.today
    if params['name'] && !params['email'].blank? && params['days']
      email_hash = Digest::MD5.hexdigest(params['email'].downcase)
      results = SurveyResult.where(['updated_at >= ? AND updated_at <= ?', start_date, end_date + 1]).where(:email_hash => email_hash)

      hours = 0.0
      results.each do |sr|
        hash = SurveyResult.session_data(sr.code)
        hash['attended'] = sr.updated_at.to_i;
        hash['score'] = sr.json['answer_1']
        hash['session_note'] = sr.json['answer_2']
        hash['conf_note'] = sr.json['answer_3']
        json << hash
      end
      render json: json.sort_by{|h| h['attended'] }
    else
      render json: {error: 'no data'}
    end
  end
  
  def render_certificate
    response.headers.delete('X-Frame-Options')
    days = params['days'].to_i
    days = 60 if !days || days == 0

    start_date = (Date.today - days)
    end_date = Date.today
    if params['name'] && !params['email'].blank? && params['days']
      email_hash = Digest::MD5.hexdigest(params['email'].downcase)
      results = SurveyResult.where(['updated_at >= ? AND updated_at <= ?', start_date, end_date + 1]).where(:email_hash => email_hash)

      sessions = []
      hours = 0.0
      results.each do |sr|
        json = SurveyResult.session_data(sr.code)
        name = json['session_name'] || "Session code: #{sr.code}"
        sessions.push(name)
        hours += (json['hours'] || 1.0).round(2)
      end
      start_date = results.map(&:updated_at).min
      end_date = results.map(&:updated_at).max
      
      dates = "no dates"
      if start_date && end_date
        dates = "#{start_date.strftime('%B %e, %Y')} to #{end_date.strftime('%B %e, %Y')}"
        if start_date == end_date
          dates = "#{start_date.strftime('%B %e, %Y')}"
        end
      end
      
      
      pdf = Prawn::Document.new
      pdf.move_down 30
      pdf.text "AAC in the Cloud", :align => :center, :size => 20
      pdf.text "Certificate of Attendance", :align => :center, :size => 35
      pdf.move_down 30
      pdf.text "presented to", :align => :center, :size => 15, :color => '888888'
      pdf.move_down 20
      pdf.text params['name'], :align => :center, :size => 30
      pdf.move_up 5
      pdf.text params['email'], :align => :center, :size => 15
      pdf.move_down 25
      pdf.text "for attending the following presentation sessions:", :align => :center, :size => 15, :color => '888888'
      full_width = 450
      available_height = 240
      original_left = 50
      original_top = 450
      top = original_top
      left = original_left
      width = full_width
      height = 25
      columns = 1
      if sessions.length > 10
        columns = 2
        width = full_width / 2
        left -= 10
        if sessions.length > 20
          height = 10
        end
      end
      sessions.each do |str, idx|
#         str =  "this is some really long text that should get wrapped and truncated and stuff because that's just the way it is sometime, you know? you win some, you lose some, but that's just the way it is."
        pdf.text_box "• " + str, :at => [left, top], :width => width, :height => height, :size => height * 0.75, :overflow => :shrink_to_fit
        top -= height
        if sessions.length <= 6
          top -= 10
        end
        if top < (original_top - (available_height))
          top = original_top
          left = original_left + (full_width / 2) + 10
        end
      end
 
      pdf.move_down 300
      pdf.text "for a total of", :align => :center, :size => 15, :color => '888888'
      pdf.move_down 10
      pdf.text "#{hours.to_f.round(2)} maintenance hours", :align => :center, :size => 20
      pdf.draw_text dates, :at => [25, 25], :size => 12
      pdf.line [300, 40], [520, 40]
      pdf.stroke
      pdf.draw_text "Melissa DeMoux, conference coordinator", :at => [300, 25], :size => 12
      pdf.line_width 4
      pdf.rectangle [0, 720], 540, 720
      pdf.stroke_color "2caad3"
      pdf.stroke
      pdf.line_width 2
      pdf.rounded_polygon 2, [10, 10], 
                  [10, 680], [30, 680], [30, 670], [20, 670], [20, 710], [10, 710], 
                  [10, 700], [50, 700], [50, 690], [40, 690], [40, 710], 
                  [500, 710], [500, 690], [490, 690], [490, 700], [530, 700], [530, 710],
                  [520, 710], [520, 670], [510, 670], [510, 680],
                  [530, 680], 
                  [530, 10]
      pdf.stroke
      pdf.image "./public/md-sig.png", :at => [310, 70], :width => 200, :height => (200 * 55 / 422)
      pdf.image "./public/logo.png", :at => [35, 155], :width => 100, :height => 100
      pdf.stroke_color "2caad3"
      pdf.line_width 10
      pdf.rounded_rectangle [30, 160], 110, 110, 10
      pdf.stroke
      pdf.fill_color 'aaaaaa'
      pdf.text_box "sponsored by CoughDrop, Inc. 9733 Sharolyn Ln. South Jordan, UT 84009, info@mycoughdrop.com", :at => [0, -10], :width => 530, height: 20, :color => '888888', :align => :center, :overflow => :shrink_to_fit
      pdf.render_file "AACintheCloud-certificate.pdf"
      send_file 'AACintheCloud-certificate.pdf', :disposition => 'inline'
    else
      redirect_to action: 'certificate'
    end
  end
  
  def certificate
    response.headers.delete('X-Frame-Options')
  end
end
