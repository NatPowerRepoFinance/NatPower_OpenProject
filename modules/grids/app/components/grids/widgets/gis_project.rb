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

module Grids
  module Widgets
    class GisProject < Grids::WidgetComponent
      param :project

      def initialize(...)
        super
        @gis_data = fetch_gis_data
      end

      def title
        t(".title")
      end

      def gis_data
        @gis_data
      end

      def render?
        project.present?
      end

      def flattened_gis_data
        flatten_gis_data(gis_data || {})
      end

      def format_value_for_display(value)
        case value
        when TrueClass, FalseClass
          value.to_s.capitalize
        when Array
          value.map(&:to_s).join(", ")
        else
          value.to_s
        end
      end

      private

      def fetch_gis_data
        Rails.logger.info("GIS Project widget: Checking API key - #{api_key.present?}")
        return nil unless api_key.present?

        # GIS widget functionality disabled - external_project_id removed
        nil
      end

      def api_key
        ENV["GIS_API_KEY"]
      end

      def flatten_gis_data(data, prefix = "", result = {})
        return result unless data.is_a?(Hash)
        
        data.each do |key, value|
          current_key = prefix.present? ? "#{key.to_s.humanize}" : key.to_s.humanize

          case value
          when Hash

            flatten_gis_data(value, current_key, result)
          when Array
            if value.any? && value.first.is_a?(Hash)
              value.each_with_index do |item, index|
                item_key = "#{current_key} #{index + 1}"
                flatten_gis_data(item, item_key, result)
              end
            else
              result[current_key] = value unless value.empty?
            end
          when nil
            next
          else
            result[current_key] = value
          end
        end

        result
      end
    end
  end
end
