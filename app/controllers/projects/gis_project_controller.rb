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

class Projects::GisProjectController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def edit
    @gis_form = gis_form_defaults
  end

  def update
    attrs = permitted_gis_params.to_h.compact
    attrs["project_id"] = @project.id

    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.update_project(attrs)

    if result.respond_to?(:success?) && result.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_overview_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update)
      @gis_form = gis_form_defaults.merge(attrs)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def gis_form_defaults
    data = @project.respond_to?(:api_data) ? (@project.api_data || {}) : {}

    {
      "name" => data["name"] || data["projectName"],
      "status_code" => data["statusCode"] || data["status_code"]
      # Add more defaults here if you expose more fields
    }
  end

  def permitted_gis_params
    params.require(:gis_project).permit(
      :name,
      :status_code
      # Add other fields you want to send to the GIS update API
    )
  end
end
