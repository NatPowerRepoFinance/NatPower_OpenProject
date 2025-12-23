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

class Projects::Settings::PdaNfs::LandContractsController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[new create show edit update destroy]
  before_action :find_pda_nf_and_negotiation

  def new
    @land_contract = @land_negotiation.land_contracts_nfs.build(land_negotiation_id: @land_negotiation.id)
  end

  def create
    @land_contract = @land_negotiation.land_contracts_nfs.build(land_contract_params)
    @land_contract.land_negotiation_id = @land_negotiation.id

    if @land_contract.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_settings_pda_nf_negotiation_path(@project, @pda_nf, @land_negotiation)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: @land_contract.errors.full_messages.join(", "))
      render action: :new, status: :unprocessable_entity
    end
  end

  def show
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:id])
  end

  def edit
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:id])
  end

  def update
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:id])

    if @land_contract.update(land_contract_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_settings_pda_nf_negotiation_land_contract_path(@project, @pda_nf, @land_negotiation, @land_contract)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: @land_contract.errors.full_messages.join(", "))
      render action: :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @land_contract = @land_negotiation.land_contracts_nfs.find(params[:id])

    if @land_contract.destroy
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
end

