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

class ProjectsController < ApplicationController
  include OpTurbo::ComponentStream

  menu_item :overview
  menu_item :roadmap, only: :roadmap

  before_action :find_project, except: %i[index new create export_list_modal]
  before_action :load_query_or_deny_access, only: %i[index export_list_modal]
  before_action :authorize, only: %i[copy_form copy deactivate_work_package_attachments]
  before_action :authorize_global, only: %i[new create]
  before_action :require_admin, only: %i[destroy destroy_info]
  before_action :not_authorized_on_feature_flag_inactive,
                only: %i[new create],
                if: -> {
                  params[:workspace_type].in?(Project.workspace_types.values_at(:program, :portfolio))
                }
  before_action :find_optional_template, only: %i[new create]
  before_action :find_optional_parent, only: :new

  no_authorization_required! :index, :export_list_modal

  include SortHelper
  include PaginationHelper
  include QueriesHelper
  include ProjectsHelper
  include Queries::Loading

  current_menu_item :index do
    :projects
  end

  current_menu_item :new do
    :projects
  end

  current_menu_item :copy_form do
    :settings_general
  end

  def index # rubocop:disable Metrics/AbcSize
    respond_to do |format|
      format.html do
        flash.now[:error] = @query.errors.full_messages if @query.errors.any?

        render layout: "global", locals: { query: @query, state: :show }
      end

      format.any(*supported_export_formats) do
        export_list(@query, request.format.symbol)
      end

      format.turbo_stream do
        replace_via_turbo_stream(
          component: Projects::IndexPageHeaderComponent.new(query: @query, current_user:, state: :show, params:)
        )
        update_via_turbo_stream(
          component: Filter::FilterButtonComponent.new(query: @query, disable_buttons: false)
        )
        replace_via_turbo_stream(component: Projects::TableComponent.new(query: @query, current_user:, params:))

        current_url = url_for(params.permit(:controller, :action, :query_id, :filters, :columns, :sortBy, :page, :per_page))
        turbo_streams << turbo_stream.push_state(current_url)
        turbo_streams << turbo_stream.turbo_frame_set_src(
          "projects_sidemenu",
          projects_menu_url(query_id: @query.id, controller_path: "projects")
        )

        turbo_streams << turbo_stream.replace("flash-messages", helpers.render_flash_messages)

        render turbo_stream: turbo_streams
      end
    end
  end

  def new
    if from_template?
      new_from_template
    else
      new_blank
    end
  end

  def create
    if from_template?
      create_from_template
    else
      create_blank
    end
  end

  def copy_form
    @copy_options = Projects::CopyOptions.new
    @target_project = Projects::CopyService
      .new(user: current_user, source: @project, contract_options: { validate_model: false })
      .call(target_project_params: {}, attributes_only: true)
      .result

    render
  end

  def copy # rubocop:disable Metrics/AbcSize
    @copy_options = Projects::CopyOptions.new(permitted_params.copy_project_options)

    service_call = Projects::EnqueueCopyService
      .new(user: current_user, model: @project)
      .call(
        target_project_params: permitted_params.new_project.to_h,
        only: @copy_options.dependencies,
        send_notifications: @copy_options.send_notifications
      )

    if service_call.success?
      job = service_call.result
      redirect_to job_status_path(job.job_id)
    else
      @target_project = service_call.result
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: service_call.message)
      render action: :copy_form, status: :unprocessable_entity
    end
  end

  # Delete @project
  def destroy
    service_call = ::Projects::ScheduleDeletionService
                    .new(user: current_user, model: @project)
                    .call

    if service_call.success?
      flash[:notice] = I18n.t("projects.delete.scheduled")
    else
      flash[:error] = I18n.t("projects.delete.schedule_failed", errors: service_call.errors.full_messages.join("\n"))
    end

    redirect_to projects_path, status: :see_other
  end

  def destroy_info
    respond_with_dialog Projects::DeleteDialogComponent.new(project: @project)
  end

  def deactivate_work_package_attachments
    call = Projects::UpdateService
             .new(user: current_user, model: @project, contract_class: Projects::SettingsContract)
             .call(deactivate_work_package_attachments: params[:value] != "1")

    if call.failure?
      render json: call.errors.full_messages.join(" "), status: :unprocessable_entity
    else
      head :no_content
    end
  end

  def export_list_modal
    respond_with_dialog Projects::ExportListModalComponent.new(query: @query)
  end

  private

  def from_template? = @template.present?

  def new_blank
    @new_project = @parent&.children&.build(params.permit(:workspace_type)) || Project.new(params.permit(:workspace_type))
  end

  def new_from_template
    @copy_options = Projects::CopyOptions.new
    @new_project = Projects::CopyService
      .new(user: current_user, source: @template, contract_options: { validate_model: false })
      .call(target_project_params: params.permit(:parent_id).to_h, attributes_only: true)
      .result
  end

  def create_blank
    project_params = permitted_params.new_project
    pda_nfs_attrs = project_params[:pda_nfs_attributes]&.first || {}

    # Step 1: Create cluster project using project name
    gis_service = GisAPI::GisApiService.new
    cluster_result = gis_service.create_project(name: project_params[:name])

    unless cluster_result.success?
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: cluster_result.message || "Failed to create cluster project")
      @new_project = Project.new(project_params.except(:pda_nfs_attributes))
      render action: :new, status: :unprocessable_entity
      return
    end

    # Extract project_id from cluster creation response
    cluster_data = cluster_result.result
    project_id = cluster_data["id"] || cluster_data[:id] || cluster_data.dig("data", "id") || cluster_data.dig(:data, :id)

    unless project_id
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: "Failed to get project ID from cluster creation response")
      @new_project = Project.new(project_params.except(:pda_nfs_attributes))
      render action: :new, status: :unprocessable_entity
      return
    end

    # Step 2: Create ERP project with all additional fields
    # Helper to convert checkbox values to boolean
    to_boolean = lambda do |value|
      return false if value.nil? || value == "" || value == "0" || value == false
      return true if value == "1" || value == true
      false
    end

    # Build ERP attributes with snake_case field names as expected by the API
    erp_attributes = {
      project_id: project_id.to_i,
      initial_name: pda_nfs_attrs[:initial_name].presence || project_params[:name],
      name: pda_nfs_attrs[:name].presence || project_params[:name],
      created_by: current_user.id,
      project_manager_guid: pda_nfs_attrs[:project_manager_guid].presence&.to_i || -1,
      planning_manager_guid: pda_nfs_attrs[:planning_manager_guid].presence&.to_i || -1,
      land_manager_guid: pda_nfs_attrs[:land_manager_guid].presence&.to_i || -1,
      mw_bess: pda_nfs_attrs[:mw_bess].presence&.to_f || 0.0,
      mw_solar: pda_nfs_attrs[:mw_solar].presence&.to_f || 0.0,
      mw_wind: pda_nfs_attrs[:mw_wind].presence&.to_f || 0.0,
      mw_hydrogen: pda_nfs_attrs[:mw_hydrogen].presence&.to_f || 0.0,
      mw_other: pda_nfs_attrs[:mw_other].presence&.to_f || 0.0,
      mw_other_description: pda_nfs_attrs[:mw_other_description].presence,
      status_code: pda_nfs_attrs[:status_code].presence&.to_i || 1,
      senior_dev_manager_guid: pda_nfs_attrs[:senior_dev_manager_guid].presence&.to_i || -1,
      project_start_date: pda_nfs_attrs[:project_start_date].presence,
      grid_application_submitted: pda_nfs_attrs[:grid_application_submitted].presence,
      planning_submission: pda_nfs_attrs[:planning_submission].presence,
      planning_determination: pda_nfs_attrs[:planning_determination].presence,
      ready_to_build: pda_nfs_attrs[:ready_to_build].presence,
      grid_connection: pda_nfs_attrs[:grid_connection].presence,
      cod: pda_nfs_attrs[:cod].presence,
      spv_id: pda_nfs_attrs[:spv_id].presence&.to_i,
      technology: pda_nfs_attrs[:technology].presence,
      mw_hydroelectric: pda_nfs_attrs[:mw_hydroelectric].presence&.to_f || 0.0,
      custom_substation: to_boolean.call(pda_nfs_attrs[:custom_substation]),
      transmisson_substation: to_boolean.call(pda_nfs_attrs[:transmisson_substation]),
      hots_date: pda_nfs_attrs[:hots_date].presence,
      land_contracts_exchaged: pda_nfs_attrs[:land_contracts_exchaged].presence,
      grid_offer_accepted_signed: pda_nfs_attrs[:grid_offer_accepted_signed].presence,
      np_uk_envisaged_rev_date: pda_nfs_attrs[:np_uk_envisaged_rev_date].presence,
      public_consultation: pda_nfs_attrs[:public_consultation].presence,
      planning_condition_discharged: pda_nfs_attrs[:planning_condition_discharged].presence,
      stage_code: pda_nfs_attrs[:stage_code].presence&.to_i || 0,
      financial_code: pda_nfs_attrs[:financial_code].presence,
      # Flag fields for date checkboxes (snake_case format)
      actual_project_start_date_flag: to_boolean.call(pda_nfs_attrs[:has_project_start_date]),
      actual_grid_application_submitted_flag: to_boolean.call(pda_nfs_attrs[:has_grid_application_submitted]),
      actual_planning_submission_flag: to_boolean.call(pda_nfs_attrs[:has_planning_submission]),
      actual_planning_determination_flag: to_boolean.call(pda_nfs_attrs[:has_planning_determination]),
      actual_ready_to_build_flag: to_boolean.call(pda_nfs_attrs[:has_ready_to_build]),
      actual_grid_connection_flag: to_boolean.call(pda_nfs_attrs[:has_grid_connection]),
      actual_cod_flag: to_boolean.call(pda_nfs_attrs[:has_cod]),
      actual_hots_date_flag: to_boolean.call(pda_nfs_attrs[:has_hots_date]),
      actual_land_contracts_exchanged_flag: to_boolean.call(pda_nfs_attrs[:has_land_contracts_exchaged]),
      actual_grid_offer_accepted_signed_flag: to_boolean.call(pda_nfs_attrs[:has_grid_offer_accepted_signed]),
      actual_np_uk_envisaged_rev_date_flag: to_boolean.call(pda_nfs_attrs[:has_np_uk_envisaged_rev_date]),
      actual_public_consultation_flag: to_boolean.call(pda_nfs_attrs[:has_public_consultation]),
      actual_planning_condition_discharged_flag: to_boolean.call(pda_nfs_attrs[:has_planning_condition_discharged])
    }.compact

    erp_result = gis_service.create_erp_project(erp_attributes)

    unless erp_result.success?
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: erp_result.message || "Failed to create ERP project")
      @new_project = Project.new(project_params.except(:pda_nfs_attributes))
      render action: :new, status: :unprocessable_entity
      return
    end

    # Both APIs succeeded - redirect to projects list
    redirect_to projects_path, notice: I18n.t(:notice_successful_create), status: :see_other
  end

  def create_from_template # rubocop:disable Metrics/AbcSize
    @copy_options = Projects::CopyOptions.new(permitted_params.copy_project_options)

    service_call = Projects::EnqueueCopyService
      .new(user: current_user, model: @template)
      .call(
        target_project_params: permitted_params.new_project.to_h,
        only: @copy_options.dependencies,
        send_notifications: @copy_options.send_notifications
      )

    if service_call.success?
      job = service_call.result
      redirect_to job_status_path(job.job_id)
    else
      @new_project = service_call.result
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason, reason: service_call.message)
      render action: :new, status: :unprocessable_entity
    end
  end

  def find_optional_template
    @template = Project.templated.visible(current_user).find(params[:template_id]) if params[:template_id].present?
  end

  def find_optional_parent
    @parent = Project.visible(current_user).find(params[:parent_id]) if params[:parent_id].present?
  end

  def export_list(query, mime_type)
    job = Projects::ExportJob.perform_later(
      export: Projects::Export.create,
      user: current_user,
      mime_type:,
      query: query.to_hash
    )

    if request.headers["Accept"]&.include?("application/json")
      render json: { job_id: job.job_id }
    else
      redirect_to job_status_path(job.job_id)
    end
  end

  def supported_export_formats
    ::Exports::Register.list_formats(Project).map(&:to_s)
  end

  def not_authorized_on_feature_flag_inactive
    render_403 unless OpenProject::FeatureDecisions.portfolio_models_active?
  end

  helper_method :supported_export_formats
end


