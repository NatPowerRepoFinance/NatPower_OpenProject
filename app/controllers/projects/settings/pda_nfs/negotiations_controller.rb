# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class Projects::Settings::PdaNfs::NegotiationsController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[show_negotiation show_land_title_api negotiation_contracts new create edit update link_contact create_contact_link]

  def new
    pda_id = params[:pda_id]
    
    unless pda_id.present?
      flash[:error] = "PDA ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    @pda_id = pda_id
    @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(pda_id: pda_id)
  end

  def create
    pda_id = params[:pda_id]
    
    unless pda_id.present?
      flash[:error] = "PDA ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    params_hash = land_negotiation_params.to_h
    
    # Use pda_id from route if not provided in params
    params_hash[:pda_id] = pda_id unless params_hash[:pda_id].present?
    
    @pda_id = pda_id
    @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(params_hash)
    
    unless current_user.present?
      flash.now[:error] = "You must be logged in to create a land negotiation."
      render :new, status: :unprocessable_entity
      return
    end
    
    # Build API payload
    api_payload = {
      projectId: @project.id.to_i,
      pdaId: params_hash[:pda_id].to_i,
      name: params_hash[:name],
      createdBy: current_user.id.to_i
    }
    
    # Add friendlyName if present (optional)
    api_payload[:friendlyName] = params_hash[:friendly_name] if params_hash[:friendly_name].present?
    
    # Call API
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.create_land_negotiation(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to by_pda_id_project_settings_pda_nfs_path(@project, pda_id: pda_id)
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to create land negotiation"
      flash.now[:error] = error_message
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    negotiation_id = params[:negotiation_id]
    pda_id = params[:pda_id] || params[:id]
    
    unless negotiation_id.present?
      flash[:error] = "Negotiation ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    @negotiation_id = negotiation_id
    @pda_id = pda_id
    
    # Fetch negotiation data from API to pre-fill the form
    gis_service = ::GisAPI::GisApiService.new
    
    # Try to get negotiation data from PDA API response
    if pda_id.present?
      pda_result = gis_service.get_pda(pda_id)
      if pda_result.respond_to?(:success?) && pda_result.success?
        pda_data = pda_result.result
        if pda_data["negotiationRel"].present? && pda_data["negotiationRel"].is_a?(Array)
          negotiation_data = pda_data["negotiationRel"].find do |neg|
            neg_id = neg["landNegotiationId"] || neg["id"]
            neg_id.to_s == negotiation_id.to_s
          end
          
          if negotiation_data.present?
            # Parse and format estimated_completion date if present
            estimated_completion_value = nil
            if negotiation_data["estimatedCompletion"].present?
              begin
                date_str = negotiation_data["estimatedCompletion"]
                # Handle ISO 8601 format with time (e.g., "2025-09-23T00:00:00Z")
                date = date_str.is_a?(String) ? Date.parse(date_str.split("T").first) : date_str
                estimated_completion_value = date.strftime("%Y-%m-%d")
              rescue ArgumentError, TypeError
                # If parsing fails, try to extract date part or use as-is
                estimated_completion_value = date_str.to_s.split("T").first if date_str.present?
              end
            elsif negotiation_data["estimated_completion"].present?
              begin
                date_str = negotiation_data["estimated_completion"]
                date = date_str.is_a?(String) ? Date.parse(date_str.split("T").first) : date_str
                estimated_completion_value = date.strftime("%Y-%m-%d")
              rescue ArgumentError, TypeError
                estimated_completion_value = date_str.to_s.split("T").first if date_str.present?
              end
            end
            
            @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(
              pda_id: pda_id,
              name: negotiation_data["name"],
              friendly_name: negotiation_data["friendlyName"] || negotiation_data["friendly_name"],
              negotiation_status: negotiation_data["negotiationStatus"] || negotiation_data["negotiation_status"],
              success_rating: negotiation_data["successRating"] || negotiation_data["success_rating"],
              estimated_completion: estimated_completion_value
            )
            
            # Fetch status lookup data
            status_result = gis_service.get_negotiation_status_lookup
            @status_options = []
            if status_result.respond_to?(:success?) && status_result.success?
              status_data = status_result.result
              @status_options = if status_data.is_a?(Hash) && status_data["data"].is_a?(Array)
                                  status_data["data"]
                                elsif status_data.is_a?(Array)
                                  status_data
                                else
                                  []
                                end
            end
            
            return
          end
        end
      end
    end
    
    # Fetch status lookup data
    gis_service = ::GisAPI::GisApiService.new
    status_result = gis_service.get_negotiation_status_lookup
    @status_options = []
    if status_result.respond_to?(:success?) && status_result.success?
      status_data = status_result.result
      @status_options = if status_data.is_a?(Hash) && status_data["data"].is_a?(Array)
                          status_data["data"]
                        elsif status_data.is_a?(Array)
                          status_data
                        else
                          []
                        end
    end
    
    # Fallback: initialize empty form
    @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(
      pda_id: pda_id,
      name: "",
      friendly_name: "",
      negotiation_status: nil,
      success_rating: "",
      estimated_completion: ""
    )
  end

  def update
    negotiation_id = params[:negotiation_id]
    pda_id = params[:pda_id] || params[:id]
    
    unless negotiation_id.present?
      flash[:error] = "Negotiation ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    params_hash = land_negotiation_params.to_h
    
    @negotiation_id = negotiation_id
    @pda_id = pda_id
    @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(params_hash)
    
    unless current_user.present?
      flash.now[:error] = "You must be logged in to update a land negotiation."
      render :edit, status: :unprocessable_entity
      return
    end
    
    # Build API payload
    api_payload = {
      landNegotiationId: negotiation_id.to_i,
      name: params_hash[:name],
      modifiedBy: current_user.id.to_i
    }
    
    # Add optional fields if present
    api_payload[:friendlyName] = params_hash[:friendly_name] if params_hash[:friendly_name].present?
    api_payload[:negotiationStatus] = params_hash[:negotiation_status].to_i if params_hash[:negotiation_status].present?
    api_payload[:successRating] = params_hash[:success_rating] if params_hash[:success_rating].present?
    
    # Format date if present
    if params_hash[:estimated_completion].present?
      begin
        date = Date.parse(params_hash[:estimated_completion])
        api_payload[:estimatedCompletion] = date.strftime("%Y-%m-%d")
      rescue ArgumentError
        # If date parsing fails, use as-is
        api_payload[:estimatedCompletion] = params_hash[:estimated_completion]
      end
    end
    
    # Call API
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.update_land_negotiation(api_payload)
    
    if result.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      # Redirect back to negotiation show page
      if @pda_id.present?
        redirect_to negotiation_by_pda_id_project_settings_pda_nfs_path(@project, pda_id: @pda_id, negotiation_id: negotiation_id)
      elsif params[:id].present?
        redirect_to negotiation_project_settings_pda_nf_path(@project, params[:id], negotiation_id: negotiation_id)
      else
        redirect_to project_settings_pda_nfs_path(@project)
      end
    else
      error_message = result.errors.full_messages.join(", ") rescue "Failed to update land negotiation"
      flash[:error] = error_message
      # Redirect back to show page with error
      if @pda_id.present?
        redirect_to negotiation_by_pda_id_project_settings_pda_nfs_path(@project, pda_id: @pda_id, negotiation_id: negotiation_id)
      elsif params[:id].present?
        redirect_to negotiation_project_settings_pda_nf_path(@project, params[:id], negotiation_id: negotiation_id)
      else
        redirect_to project_settings_pda_nfs_path(@project)
      end
    end
  end

  # Show negotiation details with landowners (API-only)
  def show_negotiation
    # Ensure @project is set (should be set by find_project_by_project_id, but double-check)
    unless @project.present?
      project_id = params[:project_id]
      if project_id.present?
        begin
          @project = Project.find_by(id: project_id.to_i) || Project.find(project_id)
        rescue ActiveRecord::RecordNotFound
          flash[:error] = "Project not found"
          redirect_to projects_path
          return
        end
      else
        flash[:error] = "Project ID is required"
        redirect_to projects_path
        return
      end
    end
    
    negotiation_id = params[:negotiation_id]
    pda_id = params[:pda_id] || params[:id]

    unless negotiation_id.present?
      flash[:error] = "Negotiation ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    # Try to find PDA database record if pda_id is provided, otherwise try to get from params
    if pda_id.present? && @project.respond_to?(:pda_nfs)
      @pda_nf = @project.pda_nfs.find_by(id: pda_id) || @project.pda_nfs.find_by(pda_id: pda_id.to_i)
      @pda_id = @pda_nf&.pda_id || pda_id
    else
      @pda_id = params[:pda_id]
    end
    
    # Fetch landowners data from API
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_landowners(negotiation_id)

    unless result.respond_to?(:success?) && result.success?
      flash[:error] = "Failed to fetch landowners data for negotiation #{negotiation_id}"
      redirect_to (@pda_id.present? ? by_pda_id_project_settings_pda_nfs_path(@project, pda_id: @pda_id) : project_settings_pda_nfs_path(@project))
      return
    end

    @landowners_data = result.result
    
    # Extract contacts and companies from API response
    # API returns: { "code": 200, "data": { "contact": [...], "company": [...] } }
    @contacts = []
    @companies = []
    
    if @landowners_data.is_a?(Hash)
      if @landowners_data["data"].is_a?(Hash)
        @contacts = @landowners_data["data"]["contact"] || []
        @companies = @landowners_data["data"]["company"] || []
      elsif @landowners_data["contact"].is_a?(Array)
        @contacts = @landowners_data["contact"]
      elsif @landowners_data["company"].is_a?(Array)
        @companies = @landowners_data["company"]
      end
    end

    # Fetch land titles with parcels for this negotiation
    @land_titles_data = []
    titles_result = gis_service.get_land_parcels(negotiation_id)
    Rails.logger.info("=== LAND TITLES DEBUG ===")
    Rails.logger.info("Negotiation ID: #{negotiation_id}")
    Rails.logger.info("Titles result success?: #{titles_result.respond_to?(:success?) ? titles_result.success? : 'N/A'}")
    Rails.logger.info("Titles result: #{titles_result.inspect}")
    
    if titles_result.respond_to?(:success?) && titles_result.success?
      titles_data = titles_result.result
      Rails.logger.info("Titles data type: #{titles_data.class}")
      Rails.logger.info("Titles data: #{titles_data.inspect}")
      
      # Handle API response format: { "code": 200, "message": null, "data": [...] }
      # Each item in data array contains: { "landTitle": {...}, "parcelIds": [...] }
      raw_data = if titles_data.is_a?(Hash) && titles_data["data"].is_a?(Array)
                   titles_data["data"]
                 elsif titles_data.is_a?(Array)
                   titles_data
                 else
                   []
                 end
      
      # Process the data to extract land titles with their parcels
      @land_titles_data = raw_data.map do |item|
        if item.is_a?(Hash) && item["landTitle"].is_a?(Hash)
          {
            "landTitle" => item["landTitle"],
            "parcelIds" => item["parcelIds"] || []
          }
        else
          nil
        end
      end.compact
      
      Rails.logger.info("Final land_titles_data count: #{@land_titles_data.length}")
      Rails.logger.info("Final land_titles_data: #{@land_titles_data.inspect}")
    else
      Rails.logger.error("Failed to fetch land titles. Result: #{titles_result.inspect}")
      if titles_result.respond_to?(:errors)
        Rails.logger.error("Errors: #{titles_result.errors.full_messages.join(', ')}")
      end
    end

    # Fetch contracts for this negotiation
    @contracts_data = []
    contracts_result = gis_service.get_contracts(negotiation_id)
    if contracts_result.respond_to?(:success?) && contracts_result.success?
      contracts_data = contracts_result.result
      # Handle API response format: { "code": 200, "message": null, "data": [...] }
      @contracts_data = if contracts_data.is_a?(Hash) && contracts_data["data"].is_a?(Array)
                         contracts_data["data"]
                       elsif contracts_data.is_a?(Array)
                         contracts_data
                       elsif contracts_data.is_a?(Hash) && contracts_data["contracts"].is_a?(Array)
                         contracts_data["contracts"]
                       elsif contracts_data.is_a?(Hash)
                         [contracts_data]
                       else
                         []
                       end
    end

    # Store negotiation ID for display
    @negotiation_id = negotiation_id
    
    # Load negotiation data for edit form
    @negotiation_form = nil
    if pda_id.present?
      pda_result = gis_service.get_pda(pda_id)
      if pda_result.respond_to?(:success?) && pda_result.success?
        pda_data = pda_result.result
        if pda_data["negotiationRel"].present? && pda_data["negotiationRel"].is_a?(Array)
          negotiation_data = pda_data["negotiationRel"].find do |neg|
            neg_id = neg["landNegotiationId"] || neg["id"]
            neg_id.to_s == negotiation_id.to_s
          end
          
          if negotiation_data.present?
            # Parse and format estimated_completion date if present
            estimated_completion_value = nil
            if negotiation_data["estimatedCompletion"].present?
              begin
                date_str = negotiation_data["estimatedCompletion"]
                # Handle ISO 8601 format with time (e.g., "2025-09-23T00:00:00Z")
                date = date_str.is_a?(String) ? Date.parse(date_str.split("T").first) : date_str
                estimated_completion_value = date.strftime("%Y-%m-%d")
              rescue ArgumentError, TypeError
                # If parsing fails, try to extract date part or use as-is
                estimated_completion_value = date_str.to_s.split("T").first if date_str.present?
              end
            elsif negotiation_data["estimated_completion"].present?
              begin
                date_str = negotiation_data["estimated_completion"]
                date = date_str.is_a?(String) ? Date.parse(date_str.split("T").first) : date_str
                estimated_completion_value = date.strftime("%Y-%m-%d")
              rescue ArgumentError, TypeError
                estimated_completion_value = date_str.to_s.split("T").first if date_str.present?
              end
            end
            
            @negotiation_form = Projects::Settings::LandNegotiationFormObject.new(
              pda_id: @pda_id,
              name: negotiation_data["name"] || "",
              friendly_name: negotiation_data["friendlyName"] || negotiation_data["friendly_name"] || "",
              negotiation_status: negotiation_data["negotiationStatus"] || negotiation_data["negotiation_status"],
              success_rating: negotiation_data["successRating"] || negotiation_data["success_rating"],
              estimated_completion: estimated_completion_value
            )
          end
        end
      end
    end
    
    # Fetch status lookup data for the form
    status_result = gis_service.get_negotiation_status_lookup
    @status_options = []
    if status_result.respond_to?(:success?) && status_result.success?
      status_data = status_result.result
      @status_options = if status_data.is_a?(Hash) && status_data["data"].is_a?(Array)
                          status_data["data"]
                        elsif status_data.is_a?(Array)
                          status_data
                        else
                          []
                        end
    end
    
    # Fallback: initialize empty form if not found
    @negotiation_form ||= Projects::Settings::LandNegotiationFormObject.new(
      pda_id: @pda_id,
      name: "",
      friendly_name: "",
      negotiation_status: nil,
      success_rating: "",
      estimated_completion: ""
    )

    render :show
  end

  # Show land title details from API (API-only)
  def show_land_title_api
    negotiation_id = params[:negotiation_id]
    title_no = params[:title_no]
    @pda_id = params[:pda_id] || params[:id]
    @project_id = params[:project_id]

    unless negotiation_id.present? && title_no.present?
      flash[:error] = "Negotiation ID and Title Number are required"
      redirect_to (@project_id.present? ? project_settings_pda_nfs_path(@project_id) : projects_path)
      return
    end

    # Fetch land title data from API
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_land_title(negotiation_id, title_no)

    unless result.respond_to?(:success?) && result.success?
      flash[:error] = "Failed to fetch land title data for negotiation #{negotiation_id} and title #{title_no}"
      redirect_to (@project_id.present? && @pda_id.present? ? by_pda_id_project_settings_pda_nfs_path(@project_id, pda_id: @pda_id) : (@project_id.present? ? project_settings_pda_nfs_path(@project_id) : projects_path))
      return
    end

    @land_title_data = result.result
    
    # Fetch landowners (contacts and companies) from API
    # Landowners are the actual land owners for this negotiation
    @contacts = []
    @companies = []
    
    landowners_result = gis_service.get_landowners(negotiation_id)
    if landowners_result.respond_to?(:success?) && landowners_result.success?
      landowners_data = landowners_result.result
      
      if landowners_data.is_a?(Hash)
        if landowners_data["data"].is_a?(Hash)
          @contacts = landowners_data["data"]["contact"] || []
          @companies = landowners_data["data"]["company"] || []
        elsif landowners_data["contact"].is_a?(Array)
          @contacts = landowners_data["contact"]
        elsif landowners_data["company"].is_a?(Array)
          @companies = landowners_data["company"]
        end
      end
    end
    
    # Also try to extract from land_title_data if not found in landowners
    if @contacts.empty? && @companies.empty? && @land_title_data.is_a?(Hash)
      if @land_title_data["data"].is_a?(Hash)
        @contacts = @land_title_data["data"]["contact"] || [] if @contacts.empty?
        @companies = @land_title_data["data"]["company"] || [] if @companies.empty?
      elsif @land_title_data["contact"].is_a?(Array)
        @contacts = @land_title_data["contact"] if @contacts.empty?
      elsif @land_title_data["company"].is_a?(Array)
        @companies = @land_title_data["company"] if @companies.empty?
      end
    end

    # Fetch land parcels for this negotiation
    @land_parcels_data = []
    parcels_result = gis_service.get_land_parcels(negotiation_id, title_no)
    if parcels_result.respond_to?(:success?) && parcels_result.success?
      parcels_data = parcels_result.result
      # Handle API response format: { "code": 200, "message": null, "data": [...] }
      @land_parcels_data = if parcels_data.is_a?(Hash) && parcels_data["data"].is_a?(Array)
                            parcels_data["data"]
                          elsif parcels_data.is_a?(Array)
                            parcels_data
                          else
                            []
                          end
      
      # Filter parcels by landTitleId if title_no is provided
      if @land_parcels_data.any? && title_no.present?
        @land_parcels_data = @land_parcels_data.select do |parcel|
          parcel_title_id = parcel["landTitleId"] || parcel[:landTitleId] || parcel["land_title_id"] || parcel[:land_title_id]
          parcel_title_id.to_s == title_no.to_s
        end
      end
    end

    # Fetch contracts for this negotiation
    @contracts_data = []
    contracts_result = gis_service.get_contracts(negotiation_id)
    if contracts_result.respond_to?(:success?) && contracts_result.success?
      contracts_data = contracts_result.result
      # Handle API response format: { "code": 200, "message": null, "data": [...] }
      @contracts_data = if contracts_data.is_a?(Hash) && contracts_data["data"].is_a?(Array)
                         contracts_data["data"]
                       elsif contracts_data.is_a?(Array)
                         contracts_data
                       elsif contracts_data.is_a?(Hash) && contracts_data["contracts"].is_a?(Array)
                         contracts_data["contracts"]
                       elsif contracts_data.is_a?(Hash)
                         [contracts_data]
                       else
                         []
                       end
    end

    # Store IDs for display
    @negotiation_id = negotiation_id
    @title_no = title_no

    render :show_land_title_api
  end

  def negotiation_contracts
    # Ensure @project is set
    unless @project.present?
      project_id = params[:project_id]
      if project_id.present?
        @project = Project.find_by(id: project_id.to_i) || Project.find(project_id)
      else
        flash[:error] = "Project ID is required"
        redirect_to projects_path
        return
      end
    end
    
    @pda_nf = @project.pda_nfs.find(params[:pda_id] || params[:id])
    @negotiation_metadata = {
      negotiation_id: params[:negotiation_id],
      code: params[:negotiation_code],
      name: params[:negotiation_name],
      friendly_name: params[:negotiation_friendly_name]
    }

    unless @negotiation_metadata[:negotiation_id].present?
      flash[:error] = "Negotiation ID is required to view contracts."
      return redirect_to project_settings_pda_nf_path(@project, @pda_nf)
    end

    @negotiation_contracts_api_data = fetch_negotiation_contracts_api_data(@negotiation_metadata[:negotiation_id])
    @negotiation_record_for_api_contract =
      @pda_nf.land_negotiation_nfs.find_by(land_negotiation_id: @negotiation_metadata[:negotiation_id]) ||
      (@negotiation_metadata[:code].present? && @pda_nf.land_negotiation_nfs.find_by(code: @negotiation_metadata[:code]))

    if @negotiation_contracts_api_data.nil?
      @negotiation_contracts_api_data = []
      flash.now[:error] = "Unable to load contracts from the external API right now."
    end

    # Fetch land titles from API for this negotiation
    @land_titles_api_data = []
    
    # Fetch PDA data from API using GisApiService
    if @pda_nf.pda_id.present?
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_pda(@pda_nf.pda_id)
      @pda_api_data = result.success? ? result.result : nil
    end
    
    if @pda_api_data.present? && @pda_api_data["negotiationRel"].present?
      negotiation_api_data = @pda_api_data["negotiationRel"].find do |neg|
        neg_id = neg["landNegotiationId"] || neg["id"]
        # Match by land_negotiation_id or code
        neg_id == @negotiation_metadata[:negotiation_id].to_s || neg["code"] == @negotiation_metadata[:code]
      end
      
      if negotiation_api_data.present?
        # Get land titles from API for this negotiation (raw API data - not stored in DB)
        if negotiation_api_data["titleNo"].present? && negotiation_api_data["titleNo"].is_a?(Array)
          @land_titles_api_data = negotiation_api_data["titleNo"]
        end
      end
    end

    render :negotiation_contracts
  end

  def link_contact
    negotiation_id = params[:negotiation_id]
    pda_id = params[:pda_id]
    
    unless negotiation_id.present?
      flash[:error] = "Negotiation ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    # Try to find PDA database record if pda_id is provided
    if pda_id.present? && @project.respond_to?(:pda_nfs)
      @pda_nf = @project.pda_nfs.find_by(id: pda_id) || @project.pda_nfs.find_by(pda_id: pda_id.to_i)
      @pda_id = @pda_nf&.pda_id || pda_id
    else
      @pda_id = params[:pda_id]
      # Try to find pda_nf from params if available
      if params[:pda_nf_id].present?
        @pda_nf = @project.pda_nfs.find_by(id: params[:pda_nf_id])
      end
    end
    
    @negotiation_id = negotiation_id
    @land_title_id = params[:land_title_id] || params[:landTitleId]
    
    # Set default values
    @contact_link = {
      "landNegotiationId" => negotiation_id.to_i,
      "landTitleId" => @land_title_id
    }
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def create_contact_link
    negotiation_id = params[:negotiation_id]
    pda_id = params[:pda_id]
    
    unless negotiation_id.present?
      flash[:error] = "Negotiation ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end
    
    gis_service = ::GisAPI::GisApiService.new
    contact_link_params_hash = contact_link_params
    
    # Validate parameters
    validation_errors = validate_contact_link_params(contact_link_params_hash)
    if validation_errors.any?
      @negotiation_id = negotiation_id
      @pda_id = pda_id
      @contact_link = contact_link_params_hash
      flash.now[:error] = validation_errors.join(", ")
      return render :link_contact, status: :unprocessable_entity
    end
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("LINK LANDOWNER CONTACT - Request Params:")
    Rails.logger.debug(contact_link_params_hash.inspect)
    Rails.logger.debug("LINK LANDOWNER CONTACT - JSON Payload:")
    Rails.logger.debug(contact_link_params_hash.to_json)
    
    # Generate curl command for Postman/testing
    url = "https://natpower-gis-project-dev.azurewebsites.net/erp/landowner/contact"
    payload_json = contact_link_params_hash.to_json
    api_key = ENV["GIS_API_KEY"] || "YOUR_API_KEY_HERE"
    curl_command = "curl -X POST \\\n"
    curl_command += "  '#{url}' \\\n"
    curl_command += "  -H 'X-Access-Token: #{api_key}' \\\n"
    curl_command += "  -H 'Content-Type: application/json' \\\n"
    curl_command += "  -d '#{payload_json.gsub("'", "'\\''")}'"
    
    Rails.logger.info("=" * 80)
    Rails.logger.info("CURL COMMAND FOR POSTMAN/TERMINAL:")
    Rails.logger.info(curl_command)
    Rails.logger.info("")
    Rails.logger.info("POSTMAN REQUEST DETAILS:")
    Rails.logger.info("  Method: POST")
    Rails.logger.info("  URL: #{url}")
    Rails.logger.info("  Headers:")
    Rails.logger.info("    X-Access-Token: #{api_key}")
    Rails.logger.info("    Content-Type: application/json")
    Rails.logger.info("  Body (raw JSON):")
    Rails.logger.info(JSON.pretty_generate(contact_link_params_hash))
    Rails.logger.info("=" * 80)
    Rails.logger.debug("=" * 80)
    
    result = gis_service.link_landowner_contact(contact_link_params_hash)
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("LINK LANDOWNER CONTACT - API Response:")
    Rails.logger.debug("Success: #{result.success?}")
    Rails.logger.debug("Result: #{result.result.inspect}")
    Rails.logger.debug("Result class: #{result.result.class}")
    if result.respond_to?(:errors)
      Rails.logger.debug("Errors: #{result.errors.inspect}")
      if result.errors.respond_to?(:full_messages)
        Rails.logger.debug("Error messages: #{result.errors.full_messages.inspect}")
      end
    end
    Rails.logger.debug("=" * 80)
    
    # Handle API responses: 200 success, 400 validation error, 401 auth error
    response_data = result.result
    
    # Check if API returned an error code in the response (400 validation error)
    api_error_code = response_data.is_a?(Hash) ? (response_data["code"] || response_data[:code]) : nil
    api_error_message = response_data.is_a?(Hash) ? (response_data["message"] || response_data[:message]) : nil
    
    # Handle 400 validation errors
    if result.success? && api_error_code.present? && api_error_code == 400
      Rails.logger.warn("API returned validation error (400): #{api_error_message}")
      @negotiation_id = negotiation_id
      @pda_id = pda_id
      @contact_link = contact_link_params_hash
      error_message = api_error_message || "Validation error: Failed to link contact"
      flash.now[:error] = error_message
      render :link_contact, status: :unprocessable_entity
    # Handle 401 auth errors
    elsif !result.success? && result.errors.any?
      error_messages = result.errors.respond_to?(:full_messages) ? result.errors.full_messages : [result.errors.to_s]
      if error_messages.any? { |msg| msg.include?("401") || msg.include?("auth") || msg.include?("unauthorized") }
        Rails.logger.error("API returned authentication error (401)")
        @negotiation_id = negotiation_id
        @pda_id = pda_id
        @contact_link = contact_link_params_hash
        flash.now[:error] = "Authentication error: Please check your API key"
        render :link_contact, status: :unprocessable_entity
      else
        @negotiation_id = negotiation_id
        @pda_id = pda_id
        @contact_link = contact_link_params_hash
        error_message = error_messages.join(", ")
        flash.now[:error] = error_message
        render :link_contact, status: :unprocessable_entity
      end
    # Handle 200 success
    elsif result.success?
      flash[:notice] = "Contact linked successfully"
      if pda_id.present?
        redirect_to negotiation_by_pda_id_project_settings_pda_nfs_path(@project, pda_id: pda_id, negotiation_id: negotiation_id)
      else
        redirect_to project_settings_pda_nfs_path(@project)
      end
    else
      @negotiation_id = negotiation_id
      @pda_id = pda_id
      @contact_link = contact_link_params_hash
      error_message = "Failed to link contact"
      flash.now[:error] = error_message
      render :link_contact, status: :unprocessable_entity
    end
  end

  private

  def land_negotiation_params
    params.require(:land_negotiation).permit(:pda_id, :name, :friendly_name, :negotiation_status, :success_rating, :estimated_completion)
  end

  def fetch_negotiation_contracts_api_data(negotiation_id)
    return nil unless negotiation_id.present?
    return nil unless api_key.present?

    begin
      url = "https://natpower-gis-project-dev.azurewebsites.net/erp/contract/#{CGI.escape(negotiation_id.to_s)}"
      Rails.logger.info("PDA API: Fetching negotiation contracts from #{url}")

      response = OpenProject.httpx.with(
        headers: {
          "X-Access-Token" => api_key,
          "Content-Type" => "application/json"
        }
      ).get(url)

      Rails.logger.info("PDA API: Negotiation contracts response status - #{response.status}")

      return nil unless response.status == 200

      data = response.json(symbolize_keys: false)
      payload = data.is_a?(Hash) ? (data["data"] || data["contracts"] || data.values_at("contract").compact.first) : data

      case payload
      when Array
        payload
      when Hash
        [payload]
      else
        []
      end
    rescue StandardError => e
      Rails.logger.error("Failed to fetch negotiation contracts data: #{e.message}")
      Rails.logger.error("Negotiation contracts backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    end
  end

  def api_key
    ENV["GIS_API_KEY"]
  end

  def contact_link_params
    permitted = params.require(:contact_link).permit(:landTitleId, :contactId, :landNegotiationId)
    
    # Build hash with string keys in camelCase format (as expected by API)
    params_hash = {}
    
    # String field
    params_hash["landTitleId"] = permitted[:landTitleId].to_s.strip if permitted[:landTitleId].present?
    
    # Numeric fields
    params_hash["contactId"] = permitted[:contactId].to_i if permitted[:contactId].present?
    params_hash["landNegotiationId"] = permitted[:landNegotiationId].to_i if permitted[:landNegotiationId].present?
    
    params_hash
  end

  def validate_contact_link_params(params_hash)
    errors = []
    
    # Rule: landTitleId is mandatory
    if params_hash["landTitleId"].blank?
      errors << "Land Title ID is required"
    end
    
    # Rule: contactId is mandatory
    if params_hash["contactId"].blank? || params_hash["contactId"].to_i.zero?
      errors << "Contact ID is required"
    end
    
    # Rule: landNegotiationId is mandatory
    if params_hash["landNegotiationId"].blank? || params_hash["landNegotiationId"].to_i.zero?
      errors << "Land Negotiation ID is required"
    end
    
    errors
  end
end



