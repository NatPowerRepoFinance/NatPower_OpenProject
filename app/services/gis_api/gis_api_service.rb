# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2024 the OpenProject GmbH
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

module GisAPI
  class GisApiService
    BASE_URL = "https://natpower-gis-project-dev.azurewebsites.net"

    def initialize
      @api_key = ENV["GIS_API_KEY"]
    end

    # Fetch all projects from the GIS API
    # @return [ServiceResult] ServiceResult with projects data
    def get_projects
      endpoint = "/project/cluster/all"
      make_request(:get, endpoint)
    end

    # Create a new project via the GIS API
    # @param name [String] The name of the project to create
    # @return [ServiceResult] ServiceResult with created project data
    def create_project(name:)
      endpoint = "/project/cluster/create"
      payload = { name: name }.to_json
      make_request(:post, endpoint, body: payload)
    end

    # Fetch project details by ID from the GIS API
    # @param project_id [String, Integer] The ID of the project to fetch
    # @return [ServiceResult] ServiceResult with project details
    def get_project(project_id)
      endpoint = "/erp/project/#{project_id}"
      make_request(:get, endpoint)
    end

    # Fetch lookup data (stages, statuses, etc.) from the GIS API
    # @return [ServiceResult] ServiceResult with lookup data
    def get_project_lookup_data
      endpoint = "/erp/project/lookupdata"
      make_request(:get, endpoint)
    end

    # Update a project via the GIS API (PATCH /erp/project/update)
    # @param attributes [Hash] Hash containing project_id and fields to update
    # @return [ServiceResult] ServiceResult with updated project data
    def update_project(attributes)
      endpoint = "/erp/project/update"
      payload = attributes.to_json
      make_request(:patch, endpoint, body: payload)
    end

    private

    attr_reader :api_key

    def make_request(method, endpoint, body: nil)
      unless api_key.present?
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, "GIS API key not configured")
        return ServiceResult.failure(errors: errors)
      end

      begin
        url = "#{BASE_URL}#{endpoint}"
        Rails.logger.info("GIS API: #{method.to_s.upcase} #{url}")

        response = OpenProject.httpx.with(
          headers: {
            "X-Access-Token" => api_key,
            "Content-Type" => "application/json"
          }
        ).public_send(method, url, body: body)


        if [200, 201].include?(response.status)
          data = response.json(symbolize_keys: false) rescue {}
          Rails.logger.info("GIS API: Data fetched successfully")
          Rails.logger.info("GIS API: Response data type: #{data.class}")
          Rails.logger.info("GIS API: Response keys: #{data.keys.inspect if data.is_a?(Hash)}")
          Rails.logger.info("GIS API: Response data (first 500 chars): #{data.inspect[0..500]}")
          ServiceResult.success(result: data)
        else
          Rails.logger.warn("GIS API: #{error_message}")
          error_message = "GIS API returned status #{response.status}"
          error_body = response.body.to_s rescue ""
          Rails.logger.warn("GIS API: #{error_message}, body: #{error_body}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          ServiceResult.failure(errors: errors)
        end
      rescue StandardError => e
        error_message = "Failed to call GIS API: #{e.message}"
        Rails.logger.error(error_message)
        Rails.logger.error("GIS API backtrace: #{e.backtrace.first(5).join("\n")}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      end
    end
  end
end

