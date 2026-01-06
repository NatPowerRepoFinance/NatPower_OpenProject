class Projects::CommentaryController < ApplicationController
  before_action :find_project_by_project_id, only: [:new, :create, :edit, :update]
  no_authorization_required! :new, :create, :edit, :update

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

  def edit
    commentary_id = params[:id]
    project_id = params[:project_id] || @project&.id
    
    unless commentary_id.present? && project_id.present?
      flash[:error] = "Commentary ID and Project ID are required"
      redirect_to project_path(@project)
      return
    end

    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_project_commentary(project_id)
    
    if result.success?
      response_data = result.result
      commentary_array = response_data["data"] || response_data[:data] || []
      @commentary = commentary_array.find { |c| (c["id"] || c[:id]).to_s == commentary_id.to_s }
      
      unless @commentary
        flash[:error] = "Commentary entry not found"
        redirect_to project_path(@project)
        return
      end
      
      @commentary_form = {
        id: @commentary["id"] || @commentary[:id],
        headline: @commentary["headline"] || @commentary[:headline] || "",
        detailedComment: @commentary["detailedComment"] || @commentary[:detailedComment] || "",
        commentDate: @commentary["commentDate"] || @commentary[:commentDate] || Date.current.strftime("%Y-%m-%d"),
        projectRating: @commentary["projectRating"] || @commentary[:projectRating] || 2
      }
    else
      flash[:error] = "Failed to fetch commentary data"
      redirect_to project_path(@project)
    end
  end

  def update
    commentary_id = params[:id]
    params_hash = commentary_params.to_h
    
    api_payload = {
      id: commentary_id.to_i,
      headline: params_hash[:headline],
      detailedComment: params_hash[:detailedComment],
      projectRating: params_hash[:projectRating].to_i
    }
    
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.update_project_commentary(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_path(@project)
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to update commentary"
      flash.now[:error] = error_message
      @commentary_form = params_hash.merge(id: commentary_id.to_i)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def commentary_params
    params.require(:commentary).permit(:headline, :detailedComment, :commentDate, :projectRating)
  end
end

