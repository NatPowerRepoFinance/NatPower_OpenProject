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

class Projects::Settings::PdaNfs::LandParcelsController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[new create show edit update destroy]
  before_action :find_pda_nf

  def new
    @land_parcel = @pda_nf.land_parcels.build(pda_id: @pda_nf.id)
  end

  def create
    @land_parcel = @pda_nf.land_parcels.build(land_parcel_params)
    @land_parcel.pda_id = @pda_nf.id

    if @land_parcel.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_path(@project, @pda_nf)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_parcel.errors.full_messages.join(", "))
      render action: :new, status: :unprocessable_entity
    end
  end

  def show
    @land_parcel = @pda_nf.land_parcels.find(params[:id])
    @land_titles = @land_parcel.land_titles_nfs.order(:land_title_id)
  end

  def edit
    @land_parcel = @pda_nf.land_parcels.find(params[:id])
  end

  def update
    @land_parcel = @pda_nf.land_parcels.find(params[:id])

    if @land_parcel.update(land_parcel_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_settings_pda_nf_land_parcel_path(@project, @pda_nf, @land_parcel)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_parcel.errors.full_messages.join(", "))
      render action: :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @land_parcel = @pda_nf.land_parcels.find(params[:id])

    if @land_parcel.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_pda_nf_path(@project, @pda_nf)
  end

  private

  def find_pda_nf
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id] || params[:id])
  end

  def land_parcel_params
    params.require(:land_parcel_nf).permit(
      :land_parcel_id,
      :land_parcel_code
    )
  end
end

