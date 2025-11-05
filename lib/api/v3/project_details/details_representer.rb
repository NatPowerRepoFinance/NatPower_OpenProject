# frozen_string_literal: true

module API
  module V3
    module ProjectDetails
      class DetailsRepresenter < ::API::Decorators::Single
        include ::API::Decorators::LinkedResource

        self_link title_getter: ->(*) { represented.name }, path: :project

        property :id
        property :project_code, render_nil: true
        property :project_financial_code, render_nil: true
        property :project_spv_name, render_nil: true
        property :project_site_name, render_nil: true
        property :project_status, render_nil: true
        property :project_stage, render_nil: true
        property :project_division, render_nil: true
        property :project_gis_object_id, render_nil: true
        property :project_gis_database_id, render_nil: true

        def _type
          "ProjectDetails"
        end
      end
    end
  end
end


