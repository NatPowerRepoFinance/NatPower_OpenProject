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
        project.present? && project.respond_to?(:api_data)
      end

      def flattened_gis_data
        return {} unless gis_data.is_a?(Hash) && gis_data.any?
        
        flattened = flatten_gis_data(gis_data)
        # Return flattened if it has data, otherwise return original (at least show something)
        flattened.any? ? flattened : gis_data
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

      def wrapper_arguments
        # Make widget full width (col-12) to display all project details
        { full_width: true }
      end

      # Map specific GIS fields to human-readable values using lookup data
      # Currently supports mapping Statuscode → status description via lookup API
      #
      # @param label [String] The flattened field label (e.g., "Statuscode")
      # @param value [Object] The raw value from the API
      # @return [Object] The mapped value (e.g., "Active") or original value if no mapping found
      def map_lookup_value(label, value)
        return value unless label.is_a?(String)

        normalized_label = label.strip.downcase

        if normalized_label == "statuscode" || normalized_label.include?("status code")
          mapped = status_description_for(value)
          return mapped if mapped.present?
        end

        value
      end

      private

      def fetch_gis_data
        return {} unless project.respond_to?(:api_data)
        
        raw_data = project.api_data
        return {} unless raw_data.is_a?(Hash) && raw_data.present?
        
        # Filter out internal Rails/API fields only
        exclude_keys = %w[code message]
        filtered = {}
        
        raw_data.each do |key, value|
          key_str = key.to_s
          next if key_str.start_with?("_")
          next if exclude_keys.include?(key_str)
          next if value.nil?
          
          filtered[key] = value
        end
        
        filtered
      end

      # Lazily fetch and cache the status lookup table from the GIS API.
      # Returns a hash like { 1 => "Active", 2 => "On Hold", ... }
      def status_lookup
        return @status_lookup if defined?(@status_lookup)

        @status_lookup = begin
          gis_service = ::GisAPI::GisApiService.new
          result = gis_service.get_project_lookup_data

          unless result.respond_to?(:success?) && result.success?
            Rails.logger.warn("GIS Project Widget: Failed to fetch lookup data for status codes")
            {}
          else

            raw = result.result
            data = if raw.is_a?(Hash)
                     raw["data"] || raw[:data] || raw
                   else
                     {}
                   end

            statuses = (data["status"] || data[:status] || []) rescue []

            statuses.each_with_object({}) do |entry, acc|
              code = entry["statusCode"] || entry[:statusCode] || entry["status_code"] || entry[:status_code]
              desc = entry["statusDescription"] || entry[:statusDescription] || entry["status_description"] || entry[:status_description]

              next unless code.present? && desc.present?

              acc[code.to_i] = desc
            end
          end
        rescue StandardError => e
          Rails.logger.error("GIS Project Widget: Error while building status lookup: #{e.message}")
          {}
        end
      end

      # Return human-readable description for a given status code, if available.
      #
      # @param value [Object] Numeric or string status code
      # @return [String, nil] Description such as "Active" or nil if not found
      def status_description_for(value)
        return nil if value.nil?

        code = value.is_a?(String) ? value.to_i : value.to_i
        status_lookup[code]
      end

      def api_key
        ENV["GIS_API_KEY"]
      end

      def flatten_gis_data(data, prefix = "", result = {})
        return result unless data.is_a?(Hash)
        
        data.each do |key, value|
          current_key = prefix.present? ? "#{prefix} #{key.to_s.humanize}" : key.to_s.humanize

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
