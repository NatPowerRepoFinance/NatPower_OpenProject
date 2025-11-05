# frozen_string_literal: true

module Projects
  module Settings
    class ProjectDetailsForm < ApplicationForm
      def before_render
        if model.new_record?
          model.project_division ||= CompanyDivision.ordered.first&.code
          model.project_status ||= "Active"
          model.project_stage ||= "Opportunity"

          model.valid? if model.project_code.blank?
        end
      end

      form do |f|
        f.text_field name: :project_code,
                     label: attribute_name(:project_code),
                     readonly: true,
                     caption: I18n.t("projects.settings.project_code_auto_generated", default: "Auto-generated on project creation")
        f.text_field name: :project_site_name, label: attribute_name(:project_site_name)
        f.text_field name: :project_financial_code, label: attribute_name(:project_financial_code)
        f.select_list name: :project_spv_name, label: attribute_name(:project_spv_name) do |list|
          list.option label: "", value: "" # Allow blank/null
          LookupSpvNf.ordered.find_each do |spv|
            list.option label: spv.spv_name, value: spv.spv_name
          end
        end
        f.select_list name: :project_division, label: attribute_name(:project_division) do |list|
          CompanyDivision.ordered.find_each do |div|
            list.option label: "#{div.label} (#{div.code})", value: div.code
          end
        end

        f.select_list name: :project_status, label: attribute_name(:project_status) do |list|
          LookupProjectStatus.ordered.find_each do |status|
            list.option label: status.label, value: status.label
          end
        end

        f.select_list name: :project_stage, label: attribute_name(:project_stage) do |list|
          LookupProjectStage.ordered.find_each do |stage|
            list.option label: stage.label, value: stage.label
          end
        end

        f.text_field name: :project_gis_object_id, label: attribute_name(:project_gis_object_id)
        f.text_field name: :project_gis_database_id, label: attribute_name(:project_gis_database_id)
      end
    end
  end
end


