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

require "securerandom"

class Projects::Settings::PdaNfsController < Projects::SettingsController
  include OpTurbo::ComponentStream

  menu_item :settings_pda_nfs

  helper_method :contract_status_label, :contract_status_badge_scheme

  skip_before_action :authorize,
                     only: %i[
                       index
                       show
                       show_by_pda_id
                       new
                       create
                       edit
                       update
                       destroy
                     ]

  def index
    @pda_nfs = @project.pda_nfs.order(created_date: :desc)
    @pda_nf = @project.pda_nfs.build(project_id: @project.id)
    render :show
  end

  def show

    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations/:id (negotiation show)
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    
      @land_contracts = @land_negotiation.land_contracts_nfs.order(:id)
      @pda_links = @land_negotiation.land_negotiation_pda_link_nfs.includes(:pda_nf).order(:id)
      
      # Fetch contracts from API
      @contracts_data = []
      negotiation_id = @land_negotiation.land_negotiation_id || @land_negotiation.id
      if negotiation_id.present?
        gis_service = ::GisAPI::GisApiService.new
        contracts_result = gis_service.get_contracts(negotiation_id.to_s)
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
      end
      
      render :show_land_negotiation
    elsif params[:id].present?
      # Regular route: pda_nfs/:id (PDA show)
      @pda_nf = @project.pda_nfs.find(params[:id])
      
      # Fetch PDA data from API using GisApiService
      if @pda_nf.pda_id.present?
        gis_service = ::GisAPI::GisApiService.new
        result = gis_service.get_pda(@pda_nf.pda_id)
        @pda_api_data = result.success? ? result.result : nil
      end
      
      # Get land negotiations from API (don't sync to database)
      @land_negotiations_api_data = []
      if @pda_api_data.present? && @pda_api_data["negotiationRel"].present? && @pda_api_data["negotiationRel"].is_a?(Array)
        @land_negotiations_api_data = @pda_api_data["negotiationRel"]
      end
      
      @land_parcels = @pda_nf.land_parcels.order(:land_parcel_id)
    else
      @pda_nfs = @project.pda_nfs.order(created_date: :desc)
      @pda_nf = @project.pda_nfs.build(project_id: @project.id)
    end
  end

  # Show PDA by API pda_id (API-only, no database manipulation)
  def show_by_pda_id
    pda_id = params[:pda_id]

    unless pda_id.present?
      flash[:error] = "PDA ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    # Fetch PDA data from API using GisApiService
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_pda(pda_id)

    unless result.respond_to?(:success?) && result.success?
      flash[:error] = "PDA with ID #{pda_id} not found in the API"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    @pda_api_data = result.result

    unless @pda_api_data.present?
      flash[:error] = "PDA with ID #{pda_id} not found in the API"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    # Extract land negotiations from API data
    @land_negotiations_api_data = []
    if @pda_api_data["negotiationRel"].present? && @pda_api_data["negotiationRel"].is_a?(Array)
      @land_negotiations_api_data = @pda_api_data["negotiationRel"]
    end

    # No database records - API only
    @land_parcels = []
    @pda_id = pda_id

    # Render the same view as regular show action
    render :show
  end


  def new
    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations/new
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.build(project_id: @project.id, pda_id: @pda_nf.id)
      render :new_land_negotiation
    else
      # Regular route: pda_nfs/new
    @pda_nf = @project.pda_nfs.build(project_id: @project.id)
    end
  end

  def create
    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.build(land_negotiation_params)
      @land_negotiation.project_id = @project.id
      @land_negotiation.pda_id = @pda_nf.id

      if @land_negotiation.save
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
      else
        flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_negotiation.errors.full_messages.join(", "))
        render :new_land_negotiation, status: :unprocessable_entity
      end
    else
      # Regular route: pda_nfs
    @pda_nf = @project.pda_nfs.build(pda_nf_params)
    @pda_nf.project_id = @project.id
    
    if @pda_nf.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_overview_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @pda_nf.errors.full_messages.join(", "))
      render action: :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations/:id/edit
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
      render :edit_land_negotiation
    else
      # Regular route: pda_nfs/:id/edit
    @pda_nf = @project.pda_nfs.find(params[:id])
    end
  end

  def update
    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations/:id
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])

      if @land_negotiation.update(land_negotiation_params)
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
      else
        flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_negotiation.errors.full_messages.join(", "))
        render :edit_land_negotiation, status: :unprocessable_entity
      end
    else
      # Regular route: pda_nfs/:id
    @pda_nf = @project.pda_nfs.find(params[:id])

    if @pda_nf.update(pda_nf_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_overview_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @pda_nf.errors.full_messages.join(", "))
      render action: :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    if params[:pda_nf_id].present?
      # Nested route: pda_nfs/:pda_nf_id/negotiations/:id
      @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
      @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])

      if @land_negotiation.destroy
        flash[:notice] = I18n.t(:notice_successful_delete)
      else
        flash[:error] = I18n.t(:notice_unsuccessful_delete)
      end

      redirect_to project_settings_pda_nf_path(@project, @pda_nf)
    else
      # Regular route: pda_nfs/:id
    @pda_nf = @project.pda_nfs.find(params[:id])

    if @pda_nf.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_general_path(@project)
    end
  end


  private

  def contract_status_lookup
    @contract_status_lookup ||= begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_contract_status_lookup

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Failed to fetch contract status lookup data")
        {}
      else
        raw = result.result
        Rails.logger.info("Contract status lookup raw response: #{raw.inspect}")
        
        # Extract data array from response
        # API response format: { "code": 200, "message": null, "data": [...] }
        statuses = if raw.is_a?(Hash) && raw["data"].is_a?(Array)
                     raw["data"]
                   elsif raw.is_a?(Hash) && raw[:data].is_a?(Array)
                     raw[:data]
                   elsif raw.is_a?(Array)
                     raw
                   else
                     []
                   end

        Rails.logger.info("Contract status lookup parsed statuses count: #{statuses.length}")

        statuses.each_with_object({}) do |entry, acc|
          # API response format: { "contractStatus": "Not Started", "id": 1 }
          # Map id (code) -> contractStatus (description)
          code = entry["id"] || entry[:id]
          desc = entry["contractStatus"] || entry[:contractStatus] || 
                 entry["contract_status"] || entry[:contract_status]

          if code.present? && desc.present?
            acc[code.to_i] = desc.to_s
            Rails.logger.debug("Contract status mapping: #{code} => #{desc}")
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error while building contract status lookup: #{e.message}")
      Rails.logger.error("Contract status lookup backtrace: #{e.backtrace.first(5).join("\n")}")
      {}
    end
  end

  def contract_status_label(status_value)
    return nil if status_value.nil?
    
    code = status_value.is_a?(String) ? status_value.to_i : status_value.to_i
    label = contract_status_lookup[code]
    
    if label.present?
      label
    else
      Rails.logger.warn("Contract status lookup: No label found for code #{code}. Available codes: #{contract_status_lookup.keys.inspect}")
      status_value.to_s
    end
  end

  def contract_status_badge_scheme(status_value)
    return :secondary if status_value.nil?
    
    label = contract_status_label(status_value)
    return :secondary unless label.present?
    
    # Map status labels to badge schemes
    # Valid schemes: [:default, :primary, :secondary, :accent, :success, :attention, :danger, :severe, :done, :sponsors]
    case label.to_s.downcase
    when "signed", "actioned"
      :success
    when "draft", "not started"
      :secondary
    when "part signed"
      :attention
    when "expired", "cancelled"
      :danger
    when "archive"
      :secondary
    else
      :secondary
    end
  end

  def fetch_pda_api_data(pda_id)
    return nil unless pda_id.present?
    return nil unless api_key.present?

    begin
      url = "https://natpower-gis-project-dev.azurewebsites.net/erp/pda/#{pda_id}"
      Rails.logger.info("PDA API: Fetching data from #{url}")
      
      response = OpenProject.httpx.with(
        headers: {
          "X-Access-Token" => api_key,
          "Content-Type" => "application/json"
        }
      ).get(url)

      Rails.logger.info("PDA API: Response status - #{response.status}")
      
      if response.status == 200
        data = response.json(symbolize_keys: false)
        Rails.logger.info("PDA API: Data fetched successfully")
        # Extract data array from response if present
        data["data"]&.first || data
      else
        Rails.logger.warn("PDA API: Non-200 status: #{response.status}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Failed to fetch PDA API data: #{e.message}")
      Rails.logger.error("Failed to fetch PDA API data - backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    end
  end


  def api_key
    ENV["GIS_API_KEY"]
  end

  def sync_api_negotiations(pda_nf, api_data)
    # This method is no longer used - negotiations are displayed directly from API
    # Keeping it for potential future use or for syncing nested entities if needed
    return unless api_data.present?
    return unless api_data["negotiationRel"].present?
    return unless api_data["negotiationRel"].is_a?(Array)

    # Don't sync negotiations to database - just display from API
    # If we need to sync contracts or PDA links in the future, we can do it here
    # but for now, negotiations are display-only from API
  end

  def sync_negotiation_land_titles(land_negotiation, negotiation_data)
    # This method is no longer used - land titles are displayed directly from API
    # Keeping it for potential future use, but land titles from API are not stored in DB
    return unless negotiation_data.present?
    
    # Don't sync land titles to database - just display from API
    # Manual land titles can still be created via CRUD actions
  end

  def sync_negotiation_contracts(land_negotiation, contracts_data)
    return unless contracts_data.is_a?(Array)

    contracts_data.each do |contract_data|
      contract_id = contract_data["contractId"] || contract_data["id"]
      next unless contract_id.present?

      contract = land_negotiation.land_contracts_nfs.find_or_initialize_by(contract_id: contract_id)

      contract.assign_attributes(
        land_negotiation_id: land_negotiation.id,
        contract_type_id: contract_data["contractTypeId"] || contract_data["contract_type_id"],
        start_date: parse_date(contract_data["startDate"] || contract_data["start_date"]),
        completion_date: parse_date(contract_data["completionDate"] || contract_data["completion_date"]),
        status: contract_data["status"],
        initial_expiry_date: parse_date(contract_data["initialExpiryDate"] || contract_data["initial_expiry_date"]),
        initial_expiry_notice_period_days: contract_data["initialExpiryNoticePeriodDays"] || contract_data["initial_expiry_notice_period_days"],
        extension_period: contract_data["extensionPeriod"] || contract_data["extension_period"],
        long_stop_date: parse_date(contract_data["longStopDate"] || contract_data["long_stop_date"]),
        contract_document_link: contract_data["contractDocumentLink"] || contract_data["contract_document_link"],
        contract_description: contract_data["contractDescription"] || contract_data["contract_description"]
      )

      contract.save(validate: false)
    end
  end

  def sync_negotiation_pda_links(land_negotiation, pda_links_data, project)
    return unless pda_links_data.is_a?(Array)

    pda_links_data.each do |pda_link_data|
      linked_pda_id = pda_link_data["pdaId"] || pda_link_data["pda_id"] || pda_link_data["id"]
      next unless linked_pda_id.present?

      # Find the linked PDA in the project
      linked_pda = project.pda_nfs.find_by(pda_id: linked_pda_id)
      next unless linked_pda.present?

      # Create link if it doesn't exist
      link = land_negotiation.land_negotiation_pda_link_nfs.find_or_create_by(
        land_negotiation_id: land_negotiation.id,
        pda_id: linked_pda.id
      )
    end
  end

  def parse_date(date_value)
    return nil unless date_value.present?
    
    case date_value
    when String
      Date.parse(date_value) rescue nil
    when Date
      date_value
    when Time, DateTime
      date_value.to_date
    else
      nil
    end
  end

  def pda_nf_params
    params.require(:pda_nf).permit(
      :pda_id,
      :initial_code,
      :code,
      :project_manager_guid,
      :planning_manager_guid,
      :land_manager_guid,
      :mw_bess,
      :mw_solar,
      :mw_wind,
      :mw_hydrogen,
      :mw_other,
      :mw_other_description,
      :technology,
      :senior_dev_manager_guid,
      :custom_substation,
      :transmisson_substation,
      :mw_hydroelectric
    )
  end

  def land_negotiation_params
    params.require(:land_negotiation_nf).permit(
      :code,
      :name,
      :friendly_name,
      :contract_status,
      :negotiation_status,
      :success_rating,
      :estimated_completion,
      :budget_id,
      :status,
      :land_negotiation_id
    )
  end

end


