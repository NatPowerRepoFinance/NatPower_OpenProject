class Projects::CommentaryController < ApplicationController
  before_action :find_project_by_project_id, only: [:new, :create]
  no_authorization_required! :new, :create

  def new
    project_id = params[:project_id] || @project&.id
    @commentary_form = {
      projectId: project_id.to_i,
      headline: "",
      detailedComment: "",
      commentDate: Date.current.strftime("%Y-%m-%d"),
      projectRating: 2
    }
  end

  def create
    params_hash = commentary_params.to_h
    
    api_payload = {
      projectId: @project.id.to_i,
      headline: params_hash[:headline],
      detailedComment: params_hash[:detailedComment],
      commentDate: params_hash[:commentDate] || Date.current.strftime("%Y-%m-%d"),
      createdBy: current_user&.id || User.current&.id || 1,
      projectRating: params_hash[:projectRating].to_i
    }
    
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.create_project_commentary(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_path(@project)
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to create commentary"
      flash.now[:error] = error_message
      @commentary_form = params_hash.merge(projectId: @project.id.to_i)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def commentary_params
    params.require(:commentary).permit(:headline, :detailedComment, :commentDate, :projectRating)
  end
end

