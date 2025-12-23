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

class Projects::Settings::PdaNfs::PdaLinksController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[new create show edit update destroy]
  before_action :find_pda_nf_and_negotiation

  def new
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.build(land_negotiation_id: @land_negotiation.id)
    @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.pluck(:id))
  end

  def create
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.build(pda_link_params)
    @pda_link.land_negotiation_id = @land_negotiation.id

    if @pda_link.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @pda_link.errors.full_messages.join(", "))
      @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.pluck(:id))
      render action: :new, status: :unprocessable_entity
    end
  end

  def show
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:id])
  end

  def edit
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:id])
    @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.where.not(id: @pda_link.pda_id).pluck(:id))
  end

  def update
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:id])

    if @pda_link.update(pda_link_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_settings_pda_nf_negotiation_pda_link_path(@project, @pda_nf, @land_negotiation, @pda_link)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @pda_link.errors.full_messages.join(", "))
      @available_pdas = @project.pda_nfs.where.not(id: @land_negotiation.linked_pdas.where.not(id: @pda_link.pda_id).pluck(:id))
      render action: :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pda_link = @land_negotiation.land_negotiation_pda_link_nfs.find(params[:id])

    if @pda_link.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
  end

  private

  def find_pda_nf_and_negotiation
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    @land_negotiation = @pda_nf.land_negotiation_nfs.find(params[:negotiation_id])
  end

  def pda_link_params
    params.require(:land_negotiation_pda_link_nf).permit(
      :pda_id
    )
  end
end

