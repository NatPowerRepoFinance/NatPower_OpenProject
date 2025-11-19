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

class Projects::Settings::PdaNfsController < Projects::SettingsController
  include OpTurbo::ComponentStream

  menu_item :settings_pda_nfs

  skip_before_action :authorize, only: %i[show new create edit update destroy]

  def show
    if params[:id].present?
      @pda_nf = @project.pda_nfs.find(params[:id])
      @pda_api_data = fetch_pda_api_data(@pda_nf.pda_id) if @pda_nf.pda_id.present?
    else
      @pda_nfs = @project.pda_nfs.order(created_date: :desc)
      @pda_nf = @project.pda_nfs.build(project_id: @project.id)
    end
  end

  def new
    @pda_nf = @project.pda_nfs.build(project_id: @project.id)
  end

  def create
    @pda_nf = @project.pda_nfs.build(pda_nf_params)

    @pda_nf.project_id = @project.id
    
    if @pda_nf.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_general_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @pda_nf.errors.full_messages.join(", "))
      render action: :new, status: :unprocessable_entity
    end
  end

  def edit
    @pda_nf = @project.pda_nfs.find(params[:id])
  end

  def update
    @pda_nf = @project.pda_nfs.find(params[:id])

    if @pda_nf.update(pda_nf_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_settings_general_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @pda_nf.errors.full_messages.join(", "))
      render action: :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pda_nf = @project.pda_nfs.find(params[:id])

    if @pda_nf.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_general_path(@project)
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

  def api_key
    ENV["GIS_API_KEY"]
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
end
