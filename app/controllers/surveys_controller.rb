class SurveysController < ApplicationController
  def index
    
  end
  
  def show
    @doc_id = params['id']
  end
  
  def create
    req = SurveyResult.process(params)
    render json: req.data || {}.to_json
  end
  
  def certificate
  end
end
