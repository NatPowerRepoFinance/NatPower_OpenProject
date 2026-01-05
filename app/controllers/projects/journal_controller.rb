class Projects::JournalController < ApplicationController
  before_action :find_project_by_project_id, only: [:new, :create, :edit, :update]
  no_authorization_required! :new, :create, :edit, :update

  def new
    project_id = params[:project_id] || @project&.id
    @journal_form = {
      projectId: project_id.to_i,
      journalText: ""
    }
  end

  def create
    params_hash = journal_params.to_h
    
    api_payload = {
      projectId: @project.id.to_i,
      journalText: params_hash[:journalText],
      createdBy: current_user&.id || User.current&.id || 1
    }
    
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.create_project_journal(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_path(@project)
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to create journal"
      flash.now[:error] = error_message
      @journal_form = params_hash.merge(projectId: @project.id.to_i)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    journal_id = params[:id]
    project_id = params[:project_id] || @project&.id
    
    unless journal_id.present? && project_id.present?
      flash[:error] = "Journal ID and Project ID are required"
      redirect_to project_path(@project)
      return
    end

    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_project_journal(project_id)
    
    if result.success?
      response_data = result.result
      journal_array = response_data["data"] || response_data[:data] || []
      @journal = journal_array.find { |j| (j["id"] || j[:id]).to_s == journal_id.to_s }
      
      unless @journal
        flash[:error] = "Journal entry not found"
        redirect_to project_path(@project)
        return
      end
      
      @journal_form = {
        id: @journal["id"] || @journal[:id],
        journalText: @journal["journalText"] || @journal[:journalText] || @journal["description"] || @journal[:description] || @journal["notes"] || @journal[:notes] || @journal["content"] || @journal[:content] || ""
      }
    else
      flash[:error] = "Failed to fetch journal data"
      redirect_to project_path(@project)
    end
  end

  def update
    journal_id = params[:id]
    params_hash = journal_params.to_h
    
    api_payload = {
      id: journal_id.to_i,
      journalText: params_hash[:journalText]
    }
    
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.update_project_journal(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_path(@project)
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to update journal"
      flash.now[:error] = error_message
      @journal_form = params_hash.merge(id: journal_id.to_i)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def journal_params
    params.require(:journal).permit(:journalText)
  end
end

