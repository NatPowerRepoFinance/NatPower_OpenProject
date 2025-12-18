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

module API
  module V3
    module Projects
      class ExternalApiProjectAdapter
        def initialize(api_data, detailed_data: nil)
          @api_data = extract_project_data(api_data)
          @detailed_data = detailed_data ? extract_project_data(detailed_data) : nil
          @details_fetched = false
        end

        # Delegate model_name to Project model for Rails path helpers
        def model_name
          Project.model_name
        end

        # Override to_param to use id instead of identifier for routes
        def to_param
          id.to_s
        end

        # Return true to indicate this is a persisted project (for menu rendering)
        def persisted?
          true
        end

        # Return false since this is not a new record
        def new_record?
          false
        end

        # Map API data fields to Project model attributes
        def id
          return nil unless @api_data.is_a?(Hash) || (@detailed_data && @detailed_data.is_a?(Hash))
          
          # fetch_details_if_needed
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          
          # Prioritize project_id (used in routes) over id (internal API id)
          id_value = data["project_id"] || data[:project_id] || data["projectId"] || data[:projectId] || 
                     data["id"] || data[:id]
          
          # Log warning if id is still nil (but don't raise error)
          if id_value.nil?
            Rails.logger.warn("ExternalApiProjectAdapter: No id found in data. Keys: #{data.keys.inspect}, data type: #{data.class}")
          end
          
          id_value
        end

        def identifier
          # Don't fetch details for basic fields - use existing data
          data = @detailed_data || @api_data
          return id.to_s unless data.is_a?(Hash)
          data["identifier"] || data[:identifier] || id.to_s
        end

        def name
          # Don't fetch details for basic fields - use existing data
          data = @detailed_data || @api_data
          return "Untitled Project" unless data.is_a?(Hash)
          data["name"] || data[:name] || data["projectName"] || data[:projectName] || "Untitled Project"
        end

        def description
          # Don't fetch details for basic fields - use existing data
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          data["description"] || data[:description]
        end

        def public
          @api_data["public"] || @api_data[:public] || false
        end

        def active
          @api_data["active"] != false && @api_data[:active] != false
        end

        def active?
          active
        end

        def being_archived?
          false # API projects don't have this state
        end

        def archived?
          !active
        end

        def created_at
          parse_date(@api_data["createdAt"] || @api_data[:createdAt] || @api_data["created_at"] || @api_data[:created_at])
        end

        def updated_at
          parse_date(@api_data["updatedAt"] || @api_data[:updatedAt] || @api_data["updated_at"] || @api_data[:updated_at])
        end

        # Delegate other methods to the original data
        def method_missing(method_name, *args, &block)
          return nil unless @api_data.is_a?(Hash)
          
          key = method_name.to_s
          if @api_data.key?(key)
            @api_data[key]
          elsif @api_data.key?(key.to_sym)
            @api_data[key.to_sym]
          else
            nil
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          return false unless @api_data.is_a?(Hash)
          
          key = method_name.to_s
          @api_data.key?(key) || @api_data.key?(key.to_sym) || super
        end

        # Return allowed permissions for API projects
        # For API projects, we allow basic view permissions
        def allowed_permissions
          # Return basic project permissions that are always available
          [:view_project]
        end

        # Stub associations that the representer might expect
        def enabled_modules
          []
        end

        def enabled_module_names
          []
        end

        # Return empty phases collection for API projects
        def phases
          # Return an empty ActiveRecord relation that can chain scopes like .active
          Project::Phase.none
        end

        # Return empty project_custom_fields collection for API projects
        def project_custom_fields
          # Return an empty ActiveRecord relation that can chain scopes like .visible
          ProjectCustomField.none
        end

        # Return children collection from API data
        # Returns an array-like object that supports basic chaining
        def children
          children_data = extract_children_from_api
          
          Rails.logger.info("ExternalApiProjectAdapter#children: Found #{children_data.length} children for project #{id}")
          
          return Project.none if children_data.empty?
          
          # Convert API children data to ExternalApiProjectAdapter instances
          children_adapters = children_data.map do |child_data|
            Rails.logger.info("ExternalApiProjectAdapter#children: Processing child: #{child_data.inspect}")
            ::API::V3::Projects::ExternalApiProjectAdapter.new(child_data)
          end
          
          # Return a simple collection wrapper that supports basic ActiveRecord-like methods
          ExternalApiProjectRelation.new(children_adapters)
        end

        # Return members collection from API data
        def members
          members_data = extract_members_from_api
          return Member.none if members_data.empty?
          
          # For now, return empty as members structure from API may differ
          Member.none
        end

        # Return news collection from API data
        def news
          news_data = extract_news_from_api
          return ::News.none if news_data.empty?
          
          # For now, return empty as news structure from API may differ
          ::News.none
        end

        # Return empty pda_nfs collection for now (focus on project details)
        def pda_nfs
          PdaNf.none
        end

        # Return empty project_storages collection for API projects
        def project_storages
          []
        end

        # Return empty shared_versions scope for API projects (used in menu rendering)
        def shared_versions
          Version.none
        end

        # Check if a module is enabled (used in menu rendering)
        def module_enabled?(module_name)
          # For API projects, return false for all modules by default
          # This can be customized based on API data if needed
          false
        end

        def parent
          nil
        end

        def parent_id
          @api_data["parentId"] || @api_data[:parentId] || @api_data["parent_id"] || @api_data[:parent_id]
        end

        # Stub hierarchy methods used by table component
        def is_descendant_of?(ancestor)
          false # API projects don't have hierarchy for now
        end

        def project_status_lookup
          nil
        end

        def status
          nil
        end

        def workspace_type
          # Don't fetch details for basic fields - use existing data
          data = @detailed_data || @api_data
          return "project" unless data.is_a?(Hash)
          
          data["workspaceType"] || data[:workspaceType] || 
          data["workspace_type"] || data[:workspace_type] || 
          "project"
        end

        def workspace_label
          case workspace_type
          when "program"
            I18n.t("label_program")
          when "portfolio"
            I18n.t("label_portfolio")
          else
            I18n.t("label_project")
          end
        end

        # Predicate methods for workspace type (matching Project model enum)
        def project?
          workspace_type == "project"
        end

        def program?
          workspace_type == "program"
        end

        def portfolio?
          workspace_type == "portfolio"
        end

        def created_date
          # Use existing data - don't fetch details (performance optimization)
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          
          data["createdDate"] || data[:createdDate] || 
          data["created_date"] || data[:created_date] ||
          created_at&.to_date ||
          (created_at ? created_at.to_date : Date.today) # Fallback to today if no date available
        end

        def last_updated
          # Use existing data - don't fetch details (performance optimization)
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          
          data["lastUpdated"] || data[:lastUpdated] ||
          data["last_updated"] || data[:last_updated] ||
          updated_at ||
          Time.current # Fallback to current time if no date available
        end

        def deleted_date
          # Use existing data - don't fetch details (performance optimization)
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          
          data["deletedDate"] || data[:deletedDate] ||
          data["deleted_date"] || data[:deleted_date]
        end

        def last_updated_date
          # Use existing data - don't fetch details (performance optimization)
          data = @detailed_data || @api_data
          return nil unless data.is_a?(Hash)
          
          data["lastUpdatedDate"] || data[:lastUpdatedDate] ||
          data["last_updated_date"] || data[:last_updated_date] ||
          updated_at&.to_date ||
          (updated_at ? updated_at.to_date : Date.today) # Fallback to today if no date available
        end

        # Return all API data for widgets/components that need to display project details
        # This returns the full API response data, prioritizing detailed_data if available
        def api_data
          # Return @detailed_data if available (from API call), otherwise @api_data
          # extract_project_data already unwraps during initialization, so return as-is
          data = @detailed_data || @api_data
          
          # If data is still wrapped (shouldn't happen, but handle it)
          if data.is_a?(Hash) && data.present?
            if data.key?("data") && data["data"].is_a?(Hash)
              data["data"]
            elsif data.key?(:data) && data[:data].is_a?(Hash)
              data[:data]
            else
              data
            end
          else
            data || {}
          end
        end

        private

        # Extract children projects from API data
        def extract_children_from_api
          data = @detailed_data || @api_data
          
          Rails.logger.info("ExternalApiProjectAdapter: Extracting children. detailed_data present: #{@detailed_data.present?}, api_data present: #{@api_data.present?}")
          Rails.logger.info("ExternalApiProjectAdapter: Data type: #{data.class}, keys: #{data.keys.inspect if data.is_a?(Hash)}")
          
          return [] unless data.is_a?(Hash)
          
          # Check various possible locations for children data
          children = data["children"] || data[:children] || 
                    data["subprojects"] || data[:subprojects] ||
                    data["childProjects"] || data[:childProjects] ||
                    data["child_projects"] || data[:child_projects] ||
                    data["data"]&.dig("children") ||
                    data["data"]&.dig(:children) || []
          
          Rails.logger.info("ExternalApiProjectAdapter: Found #{Array(children).length} children")
          
          Array(children)
        end

        # Extract members from API data
        def extract_members_from_api
          data = @detailed_data || @api_data
          return [] unless data.is_a?(Hash)
          
          members = data["members"] || data[:members] || 
                   data["memberships"] || data[:memberships] || []
          
          Array(members)
        end

        # Extract news from API data
        def extract_news_from_api
          data = @detailed_data || @api_data
          return [] unless data.is_a?(Hash)
          
          news = data["news"] || data[:news] || []
          
          Array(news)
        end


        def extract_project_data(response_data)
          # If response has nested structure with "data" key, extract it
          # But only if the response looks like a wrapper (has "code", "message", etc.)
          if response_data.is_a?(Hash)
            # Check if this looks like a wrapper response (has "code" or "message" keys)
            is_wrapper = response_data.key?("code") || response_data.key?("message") || response_data.key?(:code) || response_data.key?(:message)
            
            if is_wrapper && (response_data.key?("data") || response_data.key?(:data))
              extracted = response_data["data"] || response_data[:data]
              # Handle array case: if data is an array, extract the first element
              if extracted.is_a?(Array) && extracted.first.is_a?(Hash)
                extracted.first
              elsif extracted.is_a?(Hash)
                extracted
              else
                response_data
              end
            else
              # Not a wrapper, use as-is
              response_data
            end
          elsif response_data.is_a?(Array) && response_data.first.is_a?(Hash)
            # If response is an array of hashes, use the first one (shouldn't happen in normal flow)
            response_data.first
          else
            response_data
          end
        end

        def fetch_details_if_needed
          return if @details_fetched || @detailed_data.present?
          
          # Don't fetch details in list/index views - only fetch when viewing a single project
          # This prevents making API calls for every project in the list (performance optimization)
          # Details are already fetched in the controller when loading a single project
          return
          
          # Fetch detailed project data from API
          # Get id directly from @api_data to avoid circular dependency
          project_id = @api_data["id"] || @api_data[:id] || @api_data["projectId"] || @api_data[:projectId]
          return unless project_id
          
          begin
            gis_service = ::GisAPI::GisApiService.new
            result = gis_service.get_project(project_id)
            
            if result.success?
              @detailed_data = result.result
              @details_fetched = true
            end
          rescue StandardError => e
            Rails.logger.error("Failed to fetch project details: #{e.message}")
            @details_fetched = true # Mark as fetched to avoid retrying
          end
        end

        def parse_date(date_string)
          return nil unless date_string
          Time.parse(date_string.to_s) rescue nil
        end
      end

      # Simple relation-like wrapper for API project collections
      # Supports basic ActiveRecord-like chaining for widgets
      class ExternalApiProjectRelation
        include Enumerable
        include FinderMethods::WithMore

        def initialize(projects)
          @projects = Array(projects)
        end

        def each(&block)
          @projects.each(&block)
        end

        def visible(user)
          # Filter projects visible to the user
          # For now, return all (can be enhanced with API-based visibility check)
          self
        end

        def unscope(*args)
          # No-op for API projects
          self
        end

        def newest
          # Sort by created_at descending
          sorted = @projects.sort_by { |p| p.created_at || Time.at(0) }.reverse
          self.class.new(sorted)
        end

        def extending(module_class)
          # Extend this relation with the module
          self.extend(module_class)
          self
        end

        def limit(count)
          # Return a new relation with limited items
          self.class.new(@projects.first(count))
        end

        def first(count = nil)
          if count
            @projects.first(count)
          else
            @projects.first
          end
        end

        def empty?
          @projects.empty?
        end

        def any?
          @projects.any?
        end

        def length
          @projects.length
        end

        def size
          length
        end
      end

    end
  end
end

