# frozen_string_literal: true

module API
  module V3
    module ProjectDetails
      class DetailsAPI < ::API::OpenProjectAPI
        resources :details do
          get do
            ::API::V3::ProjectDetails::DetailsRepresenter.new(@project, current_user:)
          end

          patch do
            attributes = declared_params(include_missing: false)
            permitted = attributes.slice(:project_code, :project_financial_code, :project_spv_name,
                                         :project_site_name, :project_status, :project_stage,
                                         :project_division, :project_gis_object_id, :project_gis_database_id)

            if @project.update(permitted)
              status 200
              ::API::V3::ProjectDetails::DetailsRepresenter.new(@project, current_user:)
            else
              fail ::API::Errors::InvalidResource.new(@project)
            end
          end

          get :schema do
            ::API::V3::ProjectDetails::Schemas::DetailsSchemaRepresenter.new(@project, current_user:)
          end
        end
      end
    end
  end
end


