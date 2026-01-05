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

class AddressesController < ApplicationController
  menu_item :addresses
  no_authorization_required! :index, :new, :create, :edit, :update

  def index
    @addresses = fetch_addresses_from_api
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def new
    @address = {}
    @countries = fetch_countries_from_api
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def create
    gis_service = ::GisAPI::GisApiService.new
    address_params_hash = address_params
    
    # Validate parameters
    validation_errors = validate_address_params(address_params_hash)
    if validation_errors.any?
      @address = address_params_hash
      @countries = fetch_countries_from_api
      flash.now[:error] = validation_errors.join(", ")
      return render :new, status: :unprocessable_entity
    end
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("CREATE ADDRESS - Request Params:")
    Rails.logger.debug(address_params_hash.inspect)
    Rails.logger.debug("CREATE ADDRESS - JSON Payload:")
    Rails.logger.debug(address_params_hash.to_json)
    
    # Generate curl command for Postman/testing
    url = "https://natpower-gis-project-dev.azurewebsites.net/erp/address/create"
    payload_json = address_params_hash.to_json
    api_key = ENV["GIS_API_KEY"] || "YOUR_API_KEY_HERE"
    curl_command = "curl -X POST \\\n"
    curl_command += "  '#{url}' \\\n"
    curl_command += "  -H 'X-Access-Token: #{api_key}' \\\n"
    curl_command += "  -H 'Content-Type: application/json' \\\n"
    curl_command += "  -d '#{payload_json.gsub("'", "'\\''")}'"
    
    Rails.logger.info("=" * 80)
    Rails.logger.info("CURL COMMAND FOR POSTMAN/TERMINAL:")
    Rails.logger.info(curl_command)
    Rails.logger.info("")
    Rails.logger.info("POSTMAN REQUEST DETAILS:")
    Rails.logger.info("  Method: POST")
    Rails.logger.info("  URL: #{url}")
    Rails.logger.info("  Headers:")
    Rails.logger.info("    X-Access-Token: #{api_key}")
    Rails.logger.info("    Content-Type: application/json")
    Rails.logger.info("  Body (raw JSON):")
    Rails.logger.info(JSON.pretty_generate(address_params_hash))
    Rails.logger.info("=" * 80)
    Rails.logger.debug("=" * 80)
    
    result = gis_service.create_address(address_params_hash)
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("CREATE ADDRESS - API Response:")
    Rails.logger.debug("Success: #{result.success?}")
    Rails.logger.debug("Result: #{result.result.inspect}")
    Rails.logger.debug("Result class: #{result.result.class}")
    if result.respond_to?(:errors)
      Rails.logger.debug("Errors: #{result.errors.inspect}")
      if result.errors.respond_to?(:full_messages)
        Rails.logger.debug("Error messages: #{result.errors.full_messages.inspect}")
      end
    end
    Rails.logger.debug("=" * 80)
    
    # Handle API responses: 200 success, 400 validation error, 401 auth error
    response_data = result.result
    
    # Check if API returned an error code in the response (400 validation error)
    api_error_code = response_data.is_a?(Hash) ? (response_data["code"] || response_data[:code]) : nil
    api_error_message = response_data.is_a?(Hash) ? (response_data["message"] || response_data[:message]) : nil
    
    # Handle 400 validation errors
    if result.success? && api_error_code.present? && api_error_code == 400
      Rails.logger.warn("API returned validation error (400): #{api_error_message}")
      @address = address_params_hash
      @countries = fetch_countries_from_api
      error_message = api_error_message || "Validation error: Failed to create address"
      flash.now[:error] = error_message
      render :new, status: :unprocessable_entity
    # Handle 401 auth errors
    elsif !result.success? && result.errors.any?
      error_messages = result.errors.respond_to?(:full_messages) ? result.errors.full_messages : [result.errors.to_s]
      if error_messages.any? { |msg| msg.include?("401") || msg.include?("auth") || msg.include?("unauthorized") }
        Rails.logger.error("API returned authentication error (401)")
        @address = address_params_hash
        @countries = fetch_countries_from_api
        flash.now[:error] = "Authentication error: Please check your API key"
        render :new, status: :unprocessable_entity
      else
        @address = address_params_hash
        @countries = fetch_countries_from_api
        error_message = error_messages.join(", ")
        flash.now[:error] = error_message
        render :new, status: :unprocessable_entity
      end
    # Handle 200 success
    elsif result.success?
      flash[:notice] = "Address created successfully"
      redirect_to addresses_path
    else
      @address = address_params_hash
      @countries = fetch_countries_from_api
      error_message = "Failed to create address"
      flash.now[:error] = error_message
      render :new, status: :unprocessable_entity
    end
  end

  private

  def address_params
    permitted = params.require(:address).permit(
      :line1, :line2, :line3, :line4, :city, :county, :postCode, :countryId, :fullAddress, :isDeleted
    )
    
    # Build hash with string keys in camelCase format (as expected by API)
    params_hash = {}
    
    # String fields
    params_hash["line1"] = permitted[:line1].to_s.strip if permitted[:line1].present?
    params_hash["line2"] = permitted[:line2].to_s.strip if permitted[:line2].present?
    params_hash["line3"] = permitted[:line3].to_s.strip if permitted[:line3].present?
    params_hash["line4"] = permitted[:line4].to_s.strip if permitted[:line4].present?
    params_hash["city"] = permitted[:city].to_s.strip if permitted[:city].present?
    params_hash["county"] = permitted[:county].to_s.strip if permitted[:county].present?
    params_hash["postCode"] = permitted[:postCode].to_s.strip if permitted[:postCode].present?
    params_hash["fullAddress"] = permitted[:fullAddress].to_s.strip if permitted[:fullAddress].present?
    
    # Numeric field
    params_hash["countryId"] = permitted[:countryId].to_i if permitted[:countryId].present?
    
    # Boolean field - default isDeleted to false, but allow override if provided
    if permitted[:isDeleted].present?
      params_hash["isDeleted"] = permitted[:isDeleted] == "1" || permitted[:isDeleted] == true || permitted[:isDeleted] == "true"
    else
      params_hash["isDeleted"] = false
    end
    
    params_hash
  end

  def validate_address_params(params_hash)
    errors = []
    
    # Add validation rules here if needed
    # For now, no mandatory fields based on the example
    
    errors
  end

  def fetch_addresses_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_addresses

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Addresses: Failed to fetch addresses data")
        flash.now[:error] = "Failed to fetch addresses"
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      addresses_array = response_data["data"] || response_data[:data] || []
      return [] unless addresses_array.is_a?(Array)

      addresses_array
    rescue StandardError => e
      Rails.logger.error("Addresses: Error fetching addresses from API: #{e.message}")
      Rails.logger.error("Addresses backtrace: #{e.backtrace.first(10).join("\n")}")
      flash.now[:error] = "Error loading addresses"
      []
    end
  end

  def fetch_countries_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_countries

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Addresses: Failed to fetch countries data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      countries_array = response_data["data"] || response_data[:data] || []
      return [] unless countries_array.is_a?(Array)

      countries_array
    rescue StandardError => e
      Rails.logger.error("Addresses: Error fetching countries from API: #{e.message}")
      Rails.logger.error("Addresses backtrace: #{e.backtrace.first(10).join("\n")}")
      []
    end
  end

  def edit
    @address_id = params[:id]
    
    unless @address_id.present?
      flash[:error] = "Address ID is required"
      redirect_to addresses_path
      return
    end
    
    @address = fetch_address_by_id(@address_id)
    @countries = fetch_countries_from_api
    
    unless @address
      flash[:error] = "Address not found"
      redirect_to addresses_path
      return
    end
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def update
    gis_service = ::GisAPI::GisApiService.new
    address_params_hash = address_params
    address_id = params[:id]
    
    # Add addressId to params (mandatory for update)
    address_params_hash["addressId"] = address_id.to_i
    
    # Validate parameters
    validation_errors = validate_address_params_for_update(address_params_hash)
    if validation_errors.any?
      @address_id = address_id
      @address = address_params_hash
      @countries = fetch_countries_from_api
      flash.now[:error] = validation_errors.join(", ")
      return render :edit, status: :unprocessable_entity
    end
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("UPDATE ADDRESS - Request Params:")
    Rails.logger.debug(address_params_hash.inspect)
    Rails.logger.debug("UPDATE ADDRESS - JSON Payload:")
    Rails.logger.debug(address_params_hash.to_json)
    
    # Generate curl command for Postman/testing
    url = "https://natpower-gis-project-dev.azurewebsites.net/erp/address/update"
    payload_json = address_params_hash.to_json
    api_key = ENV["GIS_API_KEY"] || "YOUR_API_KEY_HERE"
    curl_command = "curl -X PATCH \\\n"
    curl_command += "  '#{url}' \\\n"
    curl_command += "  -H 'X-Access-Token: #{api_key}' \\\n"
    curl_command += "  -H 'Content-Type: application/json' \\\n"
    curl_command += "  -d '#{payload_json.gsub("'", "'\\''")}'"
    
    Rails.logger.info("=" * 80)
    Rails.logger.info("CURL COMMAND FOR POSTMAN/TERMINAL:")
    Rails.logger.info(curl_command)
    Rails.logger.info("")
    Rails.logger.info("POSTMAN REQUEST DETAILS:")
    Rails.logger.info("  Method: PATCH")
    Rails.logger.info("  URL: #{url}")
    Rails.logger.info("  Headers:")
    Rails.logger.info("    X-Access-Token: #{api_key}")
    Rails.logger.info("    Content-Type: application/json")
    Rails.logger.info("  Body (raw JSON):")
    Rails.logger.info(JSON.pretty_generate(address_params_hash))
    Rails.logger.info("=" * 80)
    Rails.logger.debug("=" * 80)
    
    result = gis_service.update_address(address_params_hash)
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("UPDATE ADDRESS - API Response:")
    Rails.logger.debug("Success: #{result.success?}")
    Rails.logger.debug("Result: #{result.result.inspect}")
    Rails.logger.debug("Result class: #{result.result.class}")
    if result.respond_to?(:errors)
      Rails.logger.debug("Errors: #{result.errors.inspect}")
      if result.errors.respond_to?(:full_messages)
        Rails.logger.debug("Error messages: #{result.errors.full_messages.inspect}")
      end
    end
    Rails.logger.debug("=" * 80)
    
    # Handle API responses: 200 success, 400 validation error, 401 auth error
    response_data = result.result
    
    # Check if API returned an error code in the response (400 validation error)
    api_error_code = response_data.is_a?(Hash) ? (response_data["code"] || response_data[:code]) : nil
    api_error_message = response_data.is_a?(Hash) ? (response_data["message"] || response_data[:message]) : nil
    
    # Handle 400 validation errors
    if result.success? && api_error_code.present? && api_error_code == 400
      Rails.logger.warn("API returned validation error (400): #{api_error_message}")
      @address_id = address_id
      @address = address_params_hash
      @countries = fetch_countries_from_api
      error_message = api_error_message || "Validation error: Failed to update address"
      flash.now[:error] = error_message
      render :edit, status: :unprocessable_entity
    # Handle 401 auth errors
    elsif !result.success? && result.errors.any?
      error_messages = result.errors.respond_to?(:full_messages) ? result.errors.full_messages : [result.errors.to_s]
      if error_messages.any? { |msg| msg.include?("401") || msg.include?("auth") || msg.include?("unauthorized") }
        Rails.logger.error("API returned authentication error (401)")
        @address_id = address_id
        @address = address_params_hash
        @countries = fetch_countries_from_api
        flash.now[:error] = "Authentication error: Please check your API key"
        render :edit, status: :unprocessable_entity
      else
        @address_id = address_id
        @address = address_params_hash
        @countries = fetch_countries_from_api
        error_message = error_messages.join(", ")
        flash.now[:error] = error_message
        render :edit, status: :unprocessable_entity
      end
    # Handle 200 success
    elsif result.success?
      flash[:notice] = "Address updated successfully"
      redirect_to addresses_path
    else
      @address_id = address_id
      @address = address_params_hash
      @countries = fetch_countries_from_api
      error_message = "Failed to update address"
      flash.now[:error] = error_message
      render :edit, status: :unprocessable_entity
    end
  end

  def fetch_address_by_id(address_id)
    begin
      gis_service = ::GisAPI::GisApiService.new
      # Try to find address in the list first
      addresses = fetch_addresses_from_api
      address = addresses.find do |addr|
        (addr["addressId"] || addr[:addressId] || addr["id"] || addr[:id]).to_s == address_id.to_s
      end
      
      # If not found in list, we could fetch individually, but for now return what we found
      address
    rescue StandardError => e
      Rails.logger.error("Addresses: Error fetching address by ID: #{e.message}")
      nil
    end
  end

  def validate_address_params_for_update(params_hash)
    errors = []
    
    # Rule: addressId is mandatory for update
    if params_hash["addressId"].blank? || params_hash["addressId"].to_i.zero?
      errors << "Address ID is required"
    end
    
    errors
  end
end

