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

    # Fetch PDA details by ID from the GIS API
    # @param pda_id [String, Integer] The ID of the PDA
    # @return [ServiceResult] ServiceResult with PDA details
    def get_pda(pda_id)
      endpoint = "/erp/pda/#{pda_id}"
      result = make_request(:get, endpoint)
      
      # Extract data array from response if present (some endpoints wrap data in a "data" array)
      if result.success? && result.result.is_a?(Hash)
        data = result.result
        result_data = if data["data"].is_a?(Array) && data["data"].any?
                        data["data"].first
                      else
                        data
                      end
        
        ServiceResult.success(result: result_data)
      else

        result
      end
    end

    

    # Fetch landowners by negotiation ID from the GIS API
    # @param negotiation_id [String, Integer] The ID of the negotiation
    # @return [ServiceResult] ServiceResult with landowners data
    def get_landowners(negotiation_id)
      endpoint = "/erp/landowner/#{negotiation_id}"
      make_request(:get, endpoint)
    end

    # Fetch contracts by negotiation ID from the GIS API
    # @param negotiation_id [String, Integer] The ID of the negotiation
    # @return [ServiceResult] ServiceResult with contracts data
    def get_contracts(negotiation_id)
      endpoint = "/erp/contract/#{negotiation_id}"
      make_request(:get, endpoint)
    end

    # Fetch contract status lookup data from the GIS API
    # @return [ServiceResult] ServiceResult with contract status lookup data
    def get_contract_status_lookup
      endpoint = "/erp/negotiation/contract/status"
      make_request(:get, endpoint)
    end

    # Fetch land parcels by negotiation ID from the GIS API
    # @param negotiation_id [String, Integer] The ID of the negotiation
    # @param title_no [String, Integer, nil] Optional title number to filter by specific title
    # @return [ServiceResult] ServiceResult with land parcels data
    def get_land_parcels(negotiation_id, title_no = nil)
      endpoint = if title_no.present?
                   "/erp/negotiation/landparcel/#{negotiation_id}/#{title_no}"
                 else
                   "/erp/negotiation/landparcel/#{negotiation_id}"
                 end
      url = "#{BASE_URL}#{endpoint}"

      unless api_key.present?
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, "GIS API key not configured")
        return ServiceResult.failure(errors: errors)
      end

      begin
        Rails.logger.info("GIS API: GET #{url}")
        Rails.logger.info("GIS API: Negotiation ID: #{negotiation_id}")
        Rails.logger.info("GIS API: Title No: #{title_no}") if title_no.present?

        # Make request with extended timeout for large responses
        # Land parcels endpoint can return very large JSON responses
        response = OpenProject.httpx.with(
          headers: {
            "X-Access-Token" => api_key
          },
          timeout: {
            connect_timeout: 30.0,
            read_timeout: 600.0,  # 10 minutes for very large responses
            write_timeout: 30.0,
            request_timeout: 650.0  # Overall request timeout
          }
        ).get(url)

        Rails.logger.info("GIS API: Response received, type: #{response.class}")
        
        # For HTTPX, ensure the response is fully loaded before proceeding
        # HTTPX may return the response object before body is fully downloaded for large responses
        if response.respond_to?(:read)
          Rails.logger.info("GIS API: Waiting for response to complete...")
          response.read
        end

        # Handle HTTPX::ErrorResponse - often occurs with large responses due to read timeout
        # but the nested response may contain the complete data
        actual_response = if response.is_a?(HTTPX::ErrorResponse) && response.respond_to?(:response)
                            Rails.logger.info("GIS API: Handling ErrorResponse, extracting nested response")
                            response.response
                          else
                            response
                          end



                          

        # Verify we have a valid response
        unless actual_response.respond_to?(:status)
          error_message = "Invalid response object: #{actual_response.class}"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        Rails.logger.info("GIS API: Response status: #{actual_response.status}")

        # Check response status
        unless actual_response.status == 200
          error_message = "GIS API returned status #{actual_response.status}"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # For HTTPX, ensure response body is fully loaded before reading
        # HTTPX may stream large responses, so we need to wait for completion
        if actual_response.respond_to?(:to_ary)
          # HTTPX response - ensure it's fully loaded
          Rails.logger.info("GIS API: Waiting for response body to complete...")
          # Force read the body to ensure it's fully downloaded
          begin
            # Try to read the body directly if it's available
            if actual_response.respond_to?(:body)
              body_obj = actual_response.body
              Rails.logger.info("GIS API: Body object type: #{body_obj.class}")
              Rails.logger.info("GIS API: Body object methods: #{body_obj.methods.grep(/read|to_s|body/).inspect}")
            end
          rescue => e
            Rails.logger.warn("GIS API: Error checking body: #{e.message}")
          end
        end

        # Read body completely - handle streaming/IO objects
        Rails.logger.info("GIS API: Reading response body...")
        body_str = read_response_body(actual_response)
        Rails.logger.info("GIS API: Body read, length: #{body_str.length} bytes")

        unless body_str.present?
          error_message = "GIS API returned empty response body"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Validate body completeness before parsing
        unless body_str.strip.end_with?('}') || body_str.strip.end_with?(']')
          error_message = "Response body appears truncated (length: #{body_str.length} bytes)"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Parse JSON
        data = JSON.parse(body_str)
        Rails.logger.info("GIS API: Land parcels data fetched successfully, body size: #{body_str.length} bytes")
        ServiceResult.success(result: data)

      rescue JSON::ParserError => e
        error_message = "Failed to parse JSON response: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      rescue StandardError => e
        error_message = "Failed to fetch land parcels data: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        Rails.logger.error("GIS API backtrace: #{e.backtrace.first(10).join("\n")}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      end
    end

    # Fetch land title details by negotiation ID and title number from the GIS API
    # @param negotiation_id [String, Integer] The ID of the negotiation
    # @param title_no [String] The title number
    # @return [ServiceResult] ServiceResult with land title details
    def get_land_title(negotiation_id, title_no)
      endpoint = "/erp/landowner/#{negotiation_id}/#{title_no}"
      url = "#{BASE_URL}#{endpoint}"

      unless api_key.present?
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, "GIS API key not configured")
        return ServiceResult.failure(errors: errors)
      end

      begin
        Rails.logger.info("GIS API: GET #{url}")

        # Make request with extended timeout for large responses
        # Land title endpoint can return very large JSON responses
        response = OpenProject.httpx.with(
          headers: {
            "X-Access-Token" => api_key
          },
          timeout: {
            connect_timeout: 30.0,
            read_timeout: 600.0,  # 10 minutes for very large responses
            write_timeout: 30.0,
            request_timeout: 650.0  # Overall request timeout
          }
        ).get(url)

        # Handle HTTPX::ErrorResponse - often occurs with large responses due to read timeout
        # but the nested response may contain the complete data
        actual_response = if response.is_a?(HTTPX::ErrorResponse) && response.respond_to?(:response)
                            response.response
                          else
                            response
                          end

        # Verify we have a valid response
        unless actual_response.respond_to?(:status)
          error_message = "Invalid response object: #{actual_response.class}"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Check response status
        unless actual_response.status == 200
          error_message = "GIS API returned status #{actual_response.status}"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Read body completely - handle streaming/IO objects
        body_str = read_response_body(actual_response)

        unless body_str.present?
          error_message = "GIS API returned empty response body"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Validate body completeness before parsing
        unless body_str.strip.end_with?('}') || body_str.strip.end_with?(']')
          error_message = "Response body appears truncated (length: #{body_str.length} bytes)"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Parse JSON
        data = JSON.parse(body_str)
        Rails.logger.info("GIS API: Land title data fetched successfully, body size: #{body_str.length} bytes")
        ServiceResult.success(result: data)

      rescue JSON::ParserError => e
        error_message = "Failed to parse JSON response: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      rescue StandardError => e
        error_message = "Failed to fetch land title data: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        Rails.logger.error("GIS API backtrace: #{e.backtrace.first(10).join("\n")}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      end
    end

    # Fetch cluster data by project ID from the GIS API
    # @param project_id [String, Integer] The ID of the project
    # @return [ServiceResult] ServiceResult with cluster data containing features (PDAs)
    def get_cluster(project_id)
      endpoint = "/project/cluster/#{project_id}"
      url = "#{BASE_URL}#{endpoint}"

      unless api_key.present?
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, "GIS API key not configured")
        return ServiceResult.failure(errors: errors)
      end

      begin
        Rails.logger.info("GIS API: GET #{url}")

        # Make request with extended timeout for large responses
        # Cluster endpoint can return very large JSON responses (2MB+)
        response = OpenProject.httpx.with(
          headers: {
            "X-Access-Token" => api_key
          },
          timeout: {
            connect_timeout: 30.0,
            read_timeout: 600.0,  # 10 minutes for very large responses
            write_timeout: 30.0,
            request_timeout: 650.0  # Overall request timeout
          }
        ).get(url)

        # Handle HTTPX::ErrorResponse - often occurs with large responses due to read timeout
        # but the nested response may contain the complete data
        actual_response = if response.is_a?(HTTPX::ErrorResponse) && response.respond_to?(:response)
                            response.response
                          else
                            response
                          end

        # Verify we have a valid response
        unless actual_response.respond_to?(:status)
          error_message = "Invalid response object: #{actual_response.class}"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Check response status
        unless actual_response.status == 200
          error_message = "GIS API returned status #{actual_response.status}"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Read body completely - handle streaming/IO objects
        body_str = read_response_body(actual_response)

        unless body_str.present?
          error_message = "GIS API returned empty response body"
          Rails.logger.warn("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Validate body completeness before parsing
        unless body_str.strip.end_with?('}') || body_str.strip.end_with?(']')
          error_message = "Response body appears truncated (length: #{body_str.length} bytes)"
          Rails.logger.error("GIS API: #{error_message}")
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, error_message)
          return ServiceResult.failure(errors: errors)
        end

        # Parse JSON
        data = JSON.parse(body_str)
        Rails.logger.info("GIS API: Cluster data fetched successfully, body size: #{body_str.length} bytes")
        ServiceResult.success(result: data)

      rescue JSON::ParserError => e
        error_message = "Failed to parse JSON response: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      rescue StandardError => e
        error_message = "Failed to fetch cluster data: #{e.message}"
        Rails.logger.error("GIS API: #{error_message}")
        Rails.logger.error("GIS API backtrace: #{e.backtrace.first(10).join("\n")}")
        errors = ActiveModel::Errors.new(self)
        errors.add(:base, error_message)
        ServiceResult.failure(errors: errors)
      end
    end

    # Helper method to read response body completely
    # Handles different body types (streams, strings, etc.)
    def read_response_body(response)
      return "" unless response.respond_to?(:body)

      body = response.body
      Rails.logger.info("GIS API: Body object type: #{body.class}")
      
      return "" if body.nil?

      # For HTTPX responses, try different approaches to read the body
      result = nil
      
      # Try reading as stream/IO first (most common for large responses)
      if body.respond_to?(:read)
        Rails.logger.info("GIS API: Reading body as stream/IO")
        begin
          # Read the entire stream
          result = body.read
          # If read returns nil or empty, try reading with size limit
          if result.nil? || result.empty?
            body.rewind rescue nil
            # Try reading in chunks for very large responses
            result = ""
            while chunk = body.read(1024 * 1024) # Read 1MB chunks
              result << chunk
            end
          end
        rescue => e
          Rails.logger.warn("GIS API: Error reading body as stream: #{e.message}")
          Rails.logger.warn("GIS API: Error class: #{e.class}")
        end
      end
      
      # If stream reading didn't work, try other methods
      if result.nil? || result.empty?
        if body.respond_to?(:to_s)
          Rails.logger.info("GIS API: Reading body using to_s")
          result = body.to_s
        elsif body.is_a?(String)
          Rails.logger.info("GIS API: Body is already a string")
          result = body
        elsif body.respond_to?(:each)
          Rails.logger.info("GIS API: Reading body using each (chunked)")
          result = ""
          body.each { |chunk| result << chunk.to_s }
        elsif body.respond_to?(:readpartial)
          Rails.logger.info("GIS API: Reading body using readpartial")
          result = ""
          begin
            while chunk = body.readpartial(1024 * 1024)
              result << chunk
            end
          rescue EOFError
            # End of stream
          end
        else
          # Fallback - try to convert to string
          Rails.logger.info("GIS API: Using fallback to_s conversion")
          result = body.to_s rescue ""
        end
      end
      
      Rails.logger.info("GIS API: Body read result length: #{result.length} bytes")
      result || ""
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

        data = response.json(symbolize_keys: false) rescue {}
        Rails.logger.info("GIS API: Data fetched successfully")
        Rails.logger.info("GIS API: Response data type: #{data.class}")
        Rails.logger.info("GIS API: Response keys: #{data.keys.inspect if data.is_a?(Hash)}")
        Rails.logger.info("GIS API: Response data (first 500 chars): #{data.inspect[0..500]}")
        ServiceResult.success(result: data)
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

