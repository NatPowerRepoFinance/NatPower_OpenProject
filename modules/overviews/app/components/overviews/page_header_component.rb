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

module Overviews
  class PageHeaderComponent < ApplicationComponent
    extend Dry::Initializer

    include ApplicationHelper
    include Redmine::I18n

    option :project
    option :current_user, default: -> { User.current }

    private

    def breadcrumb_items
      items = []
      
      # Only add project breadcrumb link if project has a valid identifier
      if project_valid_for_routing?
        project_id = extract_project_id_for_routes
        if project_id.present?
          items << { href: project_path(project_id), text: project.name, skip_for_mobile: true }
        else
          # Fallback: use "#" as href if no valid id (breadcrumb requires href)
          items << { href: "#", text: project.name, skip_for_mobile: true }
        end
      else
        # Fallback: use "#" as href if project is invalid (breadcrumb requires href)
        items << { href: "#", text: project.name || "Project", skip_for_mobile: true }
      end
      
      items << page_title
      items
    end

    def project_valid_for_routing?
      return false unless project.present?
      
      # Check if it's an ExternalApiProjectAdapter
      if project.is_a?(::API::V3::Projects::ExternalApiProjectAdapter)
        # Check if it has a valid id
        project_id = project.id
        return project_id.present? && project_id.to_s.present?
      end
      
      # For regular Project models, check if it responds to to_param or id
      if project.respond_to?(:to_param)
        project_id = project.to_param
        return project_id.present? && project_id.to_s.present?
      elsif project.respond_to?(:id)
        project_id = project.id
        return project_id.present?
      end
      
      true # Default to true for other cases
    end

    def extract_project_id_for_routes
      return nil unless project.present?
      
      # Handle ExternalApiProjectAdapter
      if project.is_a?(::API::V3::Projects::ExternalApiProjectAdapter)
        project_id = project.id
        return project_id.to_s if project_id.present?
        return nil
      end
      
      # Handle regular Project models
      if project.respond_to?(:to_param)
        project_id = project.to_param
        return project_id.to_s if project_id.present?
      end
      
      if project.respond_to?(:id)
        project_id = project.id
        return project_id.to_s if project_id.present?
      end
      
      nil
    end

    def page_title
      if OpenProject::FeatureDecisions.new_project_overview_active?
        I18n.t("overviews.label_home", workspace_type: project.workspace_label)
      else
        I18n.t("overviews.label_overview")
      end
    end

    def favorited?
      project.favorited_by?(current_user)
    end

    def allowed_to_select_project_custom_fields?
      current_user.allowed_in_project?(:select_project_custom_fields, project)
    end

    def allowed_to_archive?
      current_user.allowed_in_project?(:archive_project, project)
    end
  end
end
