# frozen_string_literal: true

module API
  module V3
    module ProjectDetails
      module Schemas
        class DetailsSchemaRepresenter < ::API::Decorators::SchemaRepresenter
          schema :project_code, type: "String", required: true, min_length: 5, max_length: 5
          schema :project_financial_code, type: "String", required: false, max_length: 9
          schema_with_allowed_string_collection :project_spv_name,
                                                type: "String",
                                                required: false,
                                                values_callback: ->(*) { LookupSpvNf.order(:spv_name).pluck(:spv_name).compact }
          schema :project_site_name, type: "String", required: false, max_length: 50
          schema_with_allowed_string_collection :project_status,
                                                type: "String",
                                                required: true,
                                                values_callback: ->(*) { LookupProjectStatus.order(:status_id).pluck(:label) }
          schema_with_allowed_string_collection :project_stage,
                                                type: "String",
                                                required: true,
                                                values_callback: ->(*) { LookupProjectStage.order(:stage_id).pluck(:label) }
          schema_with_allowed_string_collection :project_division,
                                                type: "String",
                                                required: true,
                                                values_callback: ->(*) { CompanyDivision.order(:label).pluck(:code) }
          schema :project_gis_object_id, type: "String", required: false
          schema :project_gis_database_id, type: "String", required: false

          class << self
            def represented_class = ::Project
          end
        end
      end
    end
  end
end


