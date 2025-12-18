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
    module Utilities
      module Endpoints
        class ExternalApiIndex
          def initialize(api_service:,
                         render_representer:,
                         self_path:)
            self.api_service = api_service
            self.render_representer = render_representer
            self.self_path = self_path
          end

          def mount
            index = self

            -> do
              index.render(self)
            end
          end

          def render(request)
            # Call the api_service (can be a lambda/proc or callable object)
            result = if api_service.respond_to?(:call)
                       api_service.call
                     else
                       api_service
                     end

            if result.success?
              data = result.result
              # Transform API data to array if needed
              projects_data = data.is_a?(Array) ? data : (data["data"] || data["projects"] || [])

              # Convert API data to adapter objects
              adapted_projects = projects_data.map do |project_data|
                ::API::V3::Projects::ExternalApiProjectAdapter.new(project_data)
              end

              # Create a simple collection wrapper
              collection = ExternalApiCollection.new(adapted_projects, request.current_user)

              render_representer.create(
                collection,
                self_link: calculated_self_path(request),
                query_params: {},
                page: 1,
                per_page: adapted_projects.length,
                current_user: request.current_user
              )
            else
              error_message = if result.errors.respond_to?(:full_messages)
                                result.errors.full_messages.join(", ")
                              else
                                result.message || "Failed to fetch projects from external API"
                              end
              raise ::API::Errors::InternalError.new(error_message)
            end
          end

          attr_accessor :api_service,
                        :render_representer,
                        :self_path

          private

          def calculated_self_path(request)
            if self_path.respond_to?(:call)
              request.instance_exec(&self_path)
            else
              request.api_v3_paths.send(self_path)
            end
          end
        end

        # Simple wrapper to make API data work with the representer
        class ExternalApiCollection
          include Enumerable

          def initialize(data, current_user)
            @data = data
            @current_user = current_user
          end

          def each(&block)
            @data.each(&block)
          end

          def length
            @data.length
          end

          def size
            length
          end

          def empty?
            @data.empty?
          end
        end
      end
    end
  end
end

