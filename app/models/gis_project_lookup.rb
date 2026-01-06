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

class GisProjectLookup
  class << self
    def all_statuses
      fetch_lookup_data[:status] || []
    end

    def all_stages
      fetch_lookup_data[:stage] || []
    end

    private

    def fetch_lookup_data
      @lookup_data ||= begin
        gis_service = GisAPI::GisApiService.new
        result = gis_service.get_project_lookup_data

        if result.success?
          data = result.result["data"] || result.result[:data] || {}
          {
            status: (data["status"] || data[:status] || []).map do |status|
              { code: status["statusCode"] || status[:statusCode], description: status["statusDescription"] || status[:statusDescription] }
            end,
            stage: (data["stage"] || data[:stage] || []).map do |stage|
              { code: stage["stageCode"] || stage[:stageCode], description: stage["stageDescription"] || stage[:stageDescription] }
            end
          }
        else
          Rails.logger.warn("Failed to fetch GIS lookup data: #{result.message}")
          { status: [], stage: [] }
        end
      end
    end
  end
end

