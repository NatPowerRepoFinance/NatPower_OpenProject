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
  skip_before_action :authorize, only: %i[show_negotiation show_land_title_api negotiation_contracts]

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

    # Store negotiation ID for display
    @negotiation_id = negotiation_id

    render :show
  end

  # Show land title details from API (API-only)
  def show_land_title_api
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
    
    negotiation_id = params[:negotiation_id]
    title_no = params[:title_no]
    @pda_id = params[:pda_id] || params[:id]

    unless negotiation_id.present? && title_no.present?
      flash[:error] = "Negotiation ID and Title Number are required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    # Fetch land title data from API
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_land_title(negotiation_id, title_no)

    unless result.respond_to?(:success?) && result.success?
      flash[:error] = "Failed to fetch land title data for negotiation #{negotiation_id} and title #{title_no}"
      redirect_to (@pda_id.present? ? by_pda_id_project_settings_pda_nfs_path(@project, pda_id: @pda_id) : project_settings_pda_nfs_path(@project))
      return
    end

    @land_title_data = result.result
    
    # Extract contacts and companies if present in the response
    @contacts = []
    @companies = []
    
    if @land_title_data.is_a?(Hash)
      if @land_title_data["data"].is_a?(Hash)
        @contacts = @land_title_data["data"]["contact"] || []
        @companies = @land_title_data["data"]["company"] || []
      elsif @land_title_data["contact"].is_a?(Array)
        @contacts = @land_title_data["contact"]
      elsif @land_title_data["company"].is_a?(Array)
        @companies = @land_title_data["company"]
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

  private

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
end



