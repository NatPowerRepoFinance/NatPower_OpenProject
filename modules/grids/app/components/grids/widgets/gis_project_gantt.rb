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
    class GisProjectGantt < Grids::WidgetComponent
      include ApplicationHelper

      param :project

      def initialize(...)
        super
        @gis_data = fetch_gis_data
      end

      def title
        t(".title")
      end

      def render?
        project.present? && project.respond_to?(:api_data) && key_dates.any?
      end

      def wrapper_arguments
        { full_width: true }
      end

      def gantt_data
        key_dates.map do |date_entry|
          {
            label: date_entry[:label],
            date: date_entry[:date].iso8601,
            formatted_date: date_entry[:formatted_date]
          }
        end.to_json
      end

      private

      def key_dates
        return [] unless @gis_data.is_a?(Hash) && @gis_data.present?

        dates = []
        
        # Project Lifecycle Dates (skip metadata dates)
        dates << build_date_entry("HoTS Date", @gis_data["hotsDate"])
        dates << build_date_entry("Project Start Date", @gis_data["prjstartDate"])
        dates << build_date_entry("Grid Application Submitted", @gis_data["gridAppSub"])
        dates << build_date_entry("Public Consultation", @gis_data["publicConsultation"])
        dates << build_date_entry("Planning Submission", @gis_data["planningSubm"])
        dates << build_date_entry("Land Contracts Exchanged", @gis_data["landContractsExchanged"])
        dates << build_date_entry("Grid Offer Accepted / Signed", @gis_data["gridOfferAcceptedSigned"])
        dates << build_date_entry("Planning Determination", @gis_data["planningDet"])
        dates << build_date_entry("Ready to Build", @gis_data["readyBuild"])
        dates << build_date_entry("Planning Conditions Discharged", @gis_data["planningConditionDischarged"])
        
        # Revenue & Delivery Milestones
        dates << build_date_entry("NP UK Envisaged Revenue Date", @gis_data["npUkEnvisagedRevDate"])
        dates << build_date_entry("Grid Connection Date", @gis_data["gridConnection"])
        dates << build_date_entry("COD (Commercial Operation Date)", @gis_data["cod"])
        
        dates.compact.sort_by { |d| d[:date] || Date.new(1900, 1, 1) }
      end


      def fetch_gis_data
        return {} unless project.respond_to?(:api_data)
        
        raw_data = project.api_data
        return {} unless raw_data.is_a?(Hash) && raw_data.present?
        
        # Handle API response format: { "code": 200, "message": null, "data": [...] }
        if raw_data["data"].is_a?(Array) && raw_data["data"].any?
          raw_data["data"].first || {}
        # Handle case where data is already extracted or is the data object itself
        elsif raw_data.key?("id") || raw_data.key?("name") || raw_data.key?("code")
          raw_data
        else
          {}
        end
      end

      def build_date_entry(label, date_value)
        return nil if date_value.nil? || date_value == ""
        
        date = parse_date(date_value)
        return nil unless date
        
        {
          label: label,
          date: date,
          formatted_date: date.strftime("%Y-%m-%d")
        }
      end

      def parse_date(date_value)
        return nil unless date_value.present?
        
        case date_value
        when String
          # Handle ISO 8601 format: "2025-09-25T08:33:49.262854Z"
          Date.parse(date_value) rescue nil
        when Date
          date_value
        when Time, DateTime
          date_value.to_date
        else
          nil
        end
      end
    end
  end
end
