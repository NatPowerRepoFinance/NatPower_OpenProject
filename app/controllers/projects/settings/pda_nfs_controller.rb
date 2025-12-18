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

  skip_before_action :authorize,
                     only: %i[
                       index
                       show
                       new
                       create
                       edit
                       update
                       destroy
                       new_land_contract
                       create_land_contract
                       show_land_contract
                       edit_land_contract
                       update_land_contract
                       destroy_land_contract
                       new_pda_link
                       create_pda_link
                       show_pda_link
                       edit_pda_link
                       update_pda_link
                       destroy_pda_link
                       new_land_parcel
                       create_land_parcel
                       show_land_parcel
                       edit_land_parcel
                       update_land_parcel
                       destroy_land_parcel
                       new_land_title
                       create_land_title
                       show_land_title
                       edit_land_title
                       update_land_title
                       destroy_land_title
                       negotiation_contracts
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
      render :show_land_negotiation
    elsif params[:id].present?
      # Regular route: pda_nfs/:id (PDA show)
      @pda_nf = @project.pda_nfs.find(params[:id])
      @pda_api_data = fetch_pda_api_data(@pda_nf.pda_id) if @pda_nf.pda_id.present?
      
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

  def negotiation_contracts
    @pda_nf = @project.pda_nfs.find(params[:id])
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
    @pda_api_data = fetch_pda_api_data(@pda_nf.pda_id) if @pda_nf.pda_id.present?
    
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

  def new_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.build(land_negotiation_id: @land_negotiation.id)
  end

  def create_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.build(land_contract_params)
    @land_contract.land_negotiation_id = @land_negotiation.id

    if @land_contract.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_contract.errors.full_messages.join(", "))
      render action: :new_land_contract, status: :unprocessable_entity
    end
  end

  def show_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:land_contract_id])
  end

  def edit_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:land_contract_id])
  end

  def update_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:land_contract_id])

    if @land_contract.update(land_contract_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to show_land_contract_project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation, @land_contract)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_contract.errors.full_messages.join(", "))
      render action: :edit_land_contract, status: :unprocessable_entity
    end
  end

  def destroy_land_contract
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:land_contract_id])

    if @land_contract.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
  end

  def new_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.build(land_negotiation_id: @land_negotiation.id)
    @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.pluck(:id))
  end

  def create_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.build(pda_link_params)
    @pda_link.land_negotiation_id = @land_negotiation.id

    if @pda_link.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @pda_link.errors.full_messages.join(", "))
      @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.pluck(:id))
      render action: :new_pda_link, status: :unprocessable_entity
    end
  end

  def show_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:pda_link_id])
  end

  def edit_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:pda_link_id])
    @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.where.not(id: @pda_link.pda_id).pluck(:id))
  end

  def update_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:pda_link_id])

    if @pda_link.update(pda_link_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to show_pda_link_project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation, @pda_link)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @pda_link.errors.full_messages.join(", "))
      @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.where.not(id: @pda_link.pda_id).pluck(:id))
      render action: :edit_pda_link, status: :unprocessable_entity
    end
  end

  def destroy_pda_link
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:id])
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:pda_link_id])

    if @pda_link.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
  end

  def new_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.build(pda_id: @pda_nf.id)
  end

  def create_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.build(land_parcel_params)
    @land_parcel.pda_id = @pda_nf.id

    if @land_parcel.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_path(@project, @pda_nf)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_parcel.errors.full_messages.join(", "))
      render action: :new_land_parcel, status: :unprocessable_entity
    end
  end

  def show_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_titles = @land_parcel.land_titles_nfs.order(:land_title_id)
  end

  def edit_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
  end

  def update_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])

    if @land_parcel.update(land_parcel_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to show_land_parcel_project_settings_pda_nf_path(@project, @pda_nf, land_parcel_id: @land_parcel.id)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_parcel.errors.full_messages.join(", "))
      render action: :edit_land_parcel, status: :unprocessable_entity
    end
  end

  def destroy_land_parcel
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])

    if @land_parcel.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_pda_nf_path(@project, @pda_nf)
  end

  def new_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.build(land_parcel_id: @land_parcel.id)
  end

  def create_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.build(land_title_params)
    @land_title.land_parcel_id = @land_parcel.id

    if @land_title.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to show_land_parcel_project_settings_pda_nf_path(@project, @pda_nf, land_parcel_id: @land_parcel.id)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_title.errors.full_messages.join(", "))
      render action: :new_land_title, status: :unprocessable_entity
    end
  end

  def show_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.find_by!(land_title_id: params[:land_title_id])
  end

  def edit_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.find_by!(land_title_id: params[:land_title_id])
  end

  def update_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.find_by!(land_title_id: params[:land_title_id])

    if @land_title.update(land_title_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to show_land_title_project_settings_pda_nf_path(@project, @pda_nf, land_parcel_id: @land_parcel.id, land_title_id: @land_title.land_title_id)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_title.errors.full_messages.join(", "))
      render action: :edit_land_title, status: :unprocessable_entity
    end
  end

  def destroy_land_title
    @pda_nf = @project.pda_nfs.find(params[:id])
    @land_parcel = @pda_nf.land_parcels.find(params[:land_parcel_id])
    @land_title = @land_parcel.land_titles_nfs.find_by!(land_title_id: params[:land_title_id])

    if @land_title.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to show_land_parcel_project_settings_pda_nf_path(@project, @pda_nf, land_parcel_id: @land_parcel.id)
  end

  private

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

  def land_contract_params
    params.require(:land_contract_nf).permit(
      :contract_id,
      :contract_type_id,
      :start_date,
      :completion_date,
      :status,
      :initial_expiry_date,
      :initial_expiry_notice_period_days,
      :extension_period,
      :long_stop_date,
      :contract_document_link,
      :contract_description
    )
  end

  def pda_link_params
    params.require(:land_negotiation_pda_link_nf).permit(
      :pda_id
    )
  end

  def land_parcel_params
    params.require(:land_parcel_nf).permit(
      :land_parcel_id,
      :land_parcel_code
    )
  end

  def land_title_params
    params.require(:land_title_nf).permit(
      :land_title_id,
      :land_registry_title_id,
      :land_registry_id,
      :land_registry_title_document_link,
      :land_registry_title_request_date
    )
  end
end


