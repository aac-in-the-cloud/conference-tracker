class SurveysController < ApplicationController
  def index
    response.headers.delete('X-Frame-Options')
  end
  
  def show
    response.headers.delete('X-Frame-Options')
    @doc_id = params['id']
  end
  
  def create
    req = SurveyResult.process(params)
    render json: req.data || {}.to_json
  end
  
  def certificate
    response.headers.delete('X-Frame-Options')
  end
end
