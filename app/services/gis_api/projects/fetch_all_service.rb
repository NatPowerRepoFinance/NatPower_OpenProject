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

module GisApi
  module Projects
    class FetchAllService
      BASE_URL = "https://natpower-gis-project-dev.azurewebsites.net/project/cluster/all"

      def self.call
        new.call
      end

      def call
        unless api_key.present?
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, "GIS API key not configured")
          return ServiceResult.failure(errors: errors)
        end

        begin
          Rails.logger.info("GIS Projects API: Fetching all projects from #{BASE_URL}")

          response = OpenProject.httpx.with(
            headers: {
              "X-Access-Token" => api_key,
              "Content-Type" => "application/json"
            }
          ).get(BASE_URL)

          Rails.logger.info("GIS Projects API: Response status - #{response.status}")

          if response.status == 200
            data = response.json(symbolize_keys: false)
            Rails.logger.info("GIS Projects API: Data fetched successfully, count: #{data.is_a?(Array) ? data.length : 'unknown'}")
            ServiceResult.success(result: data)
          else
            error_message = "GIS Projects API returned status #{response.status}"
            Rails.logger.warn("GIS Projects API: #{error_message}")
            errors = ActiveModel::Errors.new(self)
            errors.add(:base, error_message)
            ServiceResult.failure(errors: errors)
          end
        rescue StandardError => e
          error_message = "Failed to fetch projects from GIS API: #{e.message}"
          Rails.logger.error(error_message)
          Rails.logger.error("GIS Projects API backtrace: #{e.backtrace.first(5).join("\n")}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          ServiceResult.failure(errors: errors)
        end
      end

      private

      def api_key
        ENV["GIS_API_KEY"]
      end
    end
  end
end

