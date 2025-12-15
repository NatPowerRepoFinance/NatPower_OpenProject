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

module Projects
  class TableComponent < ::TableComponent
    include OpTurbo::Streamable

    options :params # We read collapsed state from params
    options :current_user # adds this option to those of the base class
    options :query

    def initialize(**)
      super(rows: [], **)
    end

    def before_render
      @model = projects(query)
      super
    end

    def initial_sort
      %i[lft asc]
    end

    def self.wrapper_key
      "projects-table"
    end

    def table_id
      "project-table"
    end

    def container_class
      "generic-table--container_visible-overflow generic-table--container_height-100"
    end

    ##
    # The project sort by is handled differently
    def quick_action_table_header(column, options)
      helpers.projects_sort_header_tag(column, query.selects.map(&:attribute), **options, param: :json)
    end

    # We don't return the project row
    # but the [project, level] array from the helper
    def rows
      @rows ||= begin
        Rails.logger.info("Building rows from model: #{model.class}, count: #{model.respond_to?(:length) ? model.length : 'unknown'}")
        result = []
        projects_with_levels_order_sensitive(model) do |project, level|
          result << [project, level]
        end
        Rails.logger.info("Rows built: #{result.length} rows")
        result
      end
    end

    def initialize_sorted_model
      helpers.sort_clear

      orders = query.orders.select(&:valid?).map { |o| [o.attribute.to_s, o.direction.to_s] }
      helpers.sort_init orders
      helpers.sort_update orders.map(&:first)
    end

    def paginated?
      true
    end

    def pagination_options
      default_pagination_options.merge(optional_pagination_options)
    end

    def default_pagination_options
      {
        allowed_params: %i[query_id filters columns sortBy],
        turbo: true
      }
    end

    def optional_pagination_options
      {}
    end

    def deactivate_class_on_lft_sort
      if sorted_by_lft?
        "spot-link_inactive"
      end
    end

    def href_only_when_not_sort_lft
      unless sorted_by_lft?
        projects_path(
          sortBy: JSON.dump([%w[lft asc]]),
          **helpers.projects_query_params.slice(*helpers.projects_query_param_names_for_sort)
        )
      end
    end

    def order_options(select, turbo: false)
      options = {
        caption: select.caption,
        sortable: sortable_column?(select)
      }

      if turbo
        options[:data] = { "turbo-stream": true }
      end

      options
    end

    def sortable_column?(select)
      sortable? && query.known_order?(select.attribute)
    end

    def use_quick_action_table_headers?
      true
    end

    def columns
      @columns ||= begin
        # Only show id and name columns since those are the only fields from the API
        [
          ::Queries::Projects::Selects::Default.new(:id),
          ::Queries::Projects::Selects::Default.new(:name)
        ]
      end
    end

    def projects(query)
      # Fetch projects from external GIS API instead of database
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_projects

      if result.success?
        data = result.result
        Rails.logger.info("GIS API response data type: #{data.class}, keys: #{data.keys.inspect if data.is_a?(Hash)}")
        
        # Transform API data to array if needed
        projects_data = if data.is_a?(Array)
                          data
                        elsif data.is_a?(Hash)
                          # Check if data has nested structure
                          if data.key?("data")
                            extracted = data["data"]
                            extracted.is_a?(Array) ? extracted : [extracted].compact
                          elsif data.key?(:data)
                            extracted = data[:data]
                            extracted.is_a?(Array) ? extracted : [extracted].compact
                          elsif data.key?("projects")
                            data["projects"]
                          elsif data.key?(:projects)
                            data[:projects]
                          else
                            []
                          end
                        else
                          []
                        end

        Rails.logger.info("Projects data count: #{projects_data.length}, sample: #{projects_data.first.inspect if projects_data.any?}")

        # Convert API data to adapter objects that behave like ActiveRecord models
        adapted_projects = projects_data.map do |project_data|
          # Ensure project_data is a hash and has an id
          if project_data.is_a?(Hash) && (project_data["id"] || project_data[:id] || project_data["projectId"] || project_data[:projectId])
            ::API::V3::Projects::ExternalApiProjectAdapter.new(project_data)
          else
            Rails.logger.warn("Skipping invalid project data: #{project_data.inspect}")
            nil
          end
        end.compact

        Rails.logger.info("Adapted projects count: #{adapted_projects.length}")

        # Create a paginated array wrapper using will_paginate
        page = helpers.page_param(params) || 1
        per_page = helpers.per_page_param(params) || 25
        
        paginated_projects = WillPaginate::Collection.create(page, per_page, adapted_projects.length) do |pager|
          offset = (page - 1) * per_page
          pager.replace(adapted_projects[offset, per_page] || [])
        end
        
        Rails.logger.info("Paginated projects count: #{paginated_projects.length}, total: #{paginated_projects.total_entries}")
        paginated_projects
      else
        # Return empty result on error
        Rails.logger.error("Failed to fetch projects from GIS API: #{result.errors.full_messages.join(', ')}")
        WillPaginate::Collection.create(1, 25, 0) do |pager|
          pager.replace([])
        end
      end
    end

    def projects_with_levels_order_sensitive(projects, &)
      # For API projects, we don't have hierarchy, so just yield each project with level 0
      # Ensure we can iterate over the collection (WillPaginate::Collection is enumerable)
      projects_array = projects.respond_to?(:to_a) ? projects.to_a : projects
      Rails.logger.info("Iterating over #{projects_array.length} projects")
      projects_array.each do |project|
        Rails.logger.info("Yielding project: id=#{project.id}, name=#{project.name}")
        yield project, 0
      end
    end

    def projects_with_level(projects, &)
      # Simplified for API projects - no hierarchy
      projects.each do |project|
        yield project, 0
      end
    end

    def favorited_project_ids
      @favorited_project_ids ||= Favorite.where(user: current_user, favorited_type: "Project").pluck(:favorited_id)
    end

    def project_phase_by_definition(definition, project)
      @project_phases_by_definition ||= Project::Phase
                                                    .visible
                                                    .index_by { |s| [s.definition_id, s.project_id] }

      @project_phases_by_definition[[definition.id, project.id]]
    end

    def sorted_by_lft?
      query.orders.first&.attribute == :lft
    end
  end
end
