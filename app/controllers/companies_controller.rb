class CompaniesController < ApplicationController
  menu_item :companies
  no_authorization_required! :index, :new, :create

  def index
    @companies = fetch_companies_from_api
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def new
    @company = {}
    @addresses = fetch_addresses_from_api
    @job_roles = fetch_job_roles_from_api
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def create
    gis_service = ::GisAPI::GisApiService.new
    company_params_hash = company_params
    
    # Validate parameters according to business rules
    validation_errors = validate_company_params(company_params_hash)
    if validation_errors.any?
      @company = company_params_hash
      @addresses = fetch_addresses_from_api
      @job_roles = fetch_job_roles_from_api
      flash.now[:error] = validation_errors.join(", ")
      return render :new, status: :unprocessable_entity
    end
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("CREATE COMPANY - Request Params:")
    Rails.logger.debug(company_params_hash.inspect)
    Rails.logger.debug("CREATE COMPANY - JSON Payload:")
    Rails.logger.debug(company_params_hash.to_json)
    
    # Generate curl command for Postman/testing
    url = "https://natpower-gis-project-dev.azurewebsites.net/erp/company/create"
    payload_json = company_params_hash.to_json
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
    Rails.logger.info(JSON.pretty_generate(company_params_hash))
    Rails.logger.info("=" * 80)
    Rails.logger.debug("=" * 80)
    
    result = gis_service.create_company(company_params_hash)
    
    Rails.logger.debug("=" * 80)
    Rails.logger.debug("CREATE COMPANY - API Response:")
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

    # Handle API responses according to spec:
    # 200 success, 400 validation error, 401 auth error
    response_data = result.result
    
    # Check if API returned an error code in the response (400 validation error)
    api_error_code = response_data.is_a?(Hash) ? (response_data["code"] || response_data[:code]) : nil
    api_error_message = response_data.is_a?(Hash) ? (response_data["message"] || response_data[:message]) : nil
    
    # Handle 400 validation errors
    if result.success? && api_error_code.present? && api_error_code == 400
      Rails.logger.warn("API returned validation error (400): #{api_error_message}")
      @company = company_params_hash
      @addresses = fetch_addresses_from_api
      @job_roles = fetch_job_roles_from_api
      error_message = api_error_message || "Validation error: Failed to create company"
      flash.now[:error] = error_message
      render :new, status: :unprocessable_entity
    # Handle 401 auth errors
    elsif !result.success? && result.errors.any?
      error_messages = result.errors.respond_to?(:full_messages) ? result.errors.full_messages : [result.errors.to_s]
      if error_messages.any? { |msg| msg.include?("401") || msg.include?("auth") || msg.include?("unauthorized") }
        Rails.logger.error("API returned authentication error (401)")
        @company = company_params_hash
        @addresses = fetch_addresses_from_api
        @job_roles = fetch_job_roles_from_api
        flash.now[:error] = "Authentication error: Please check your API key"
        render :new, status: :unprocessable_entity
      else
        @company = company_params_hash
        @addresses = fetch_addresses_from_api
        @job_roles = fetch_job_roles_from_api
        error_message = error_messages.join(", ")
        flash.now[:error] = error_message
        render :new, status: :unprocessable_entity
      end
    # Handle 200 success
    elsif result.success?
      flash[:notice] = "Company created successfully"
      redirect_to companies_path
    else
      @company = company_params_hash
      @addresses = fetch_addresses_from_api
      @job_roles = fetch_job_roles_from_api
      error_message = "Failed to create company"
      flash.now[:error] = error_message
      render :new, status: :unprocessable_entity
    end
  end

  private

  def company_params
    permitted = params.require(:company).permit(
      :name, :website, :companyNumber, :taxNumber, :vatRate, :withHoldingTax,
      :withHoldingTaxRate, :paymentTerms, :earlyPaymentDiscount,
      :latePaymentPenalties, :isDeleted,
      addressesRel: {},
      contactRel: {}
    )
    
    # Build hash with string keys in camelCase format (as expected by API)
    params_hash = {}
    
    # Basic fields - convert to proper types and use camelCase string keys
    params_hash["name"] = permitted[:name].to_s.strip if permitted[:name].present?
    params_hash["website"] = permitted[:website].to_s.strip if permitted[:website].present?
    params_hash["companyNumber"] = permitted[:companyNumber].to_s.strip if permitted[:companyNumber].present?
    params_hash["taxNumber"] = permitted[:taxNumber].to_s.strip if permitted[:taxNumber].present?
    
    # Numeric fields - allow decimals
    params_hash["vatRate"] = permitted[:vatRate].to_f if permitted[:vatRate].present?
    params_hash["withHoldingTaxRate"] = permitted[:withHoldingTaxRate].to_f if permitted[:withHoldingTaxRate].present?
    params_hash["paymentTerms"] = permitted[:paymentTerms].to_i if permitted[:paymentTerms].present?
    params_hash["earlyPaymentDiscount"] = permitted[:earlyPaymentDiscount].to_f if permitted[:earlyPaymentDiscount].present?
    params_hash["latePaymentPenalties"] = permitted[:latePaymentPenalties].to_f if permitted[:latePaymentPenalties].present?
    
    # Boolean fields - default isDeleted to false
    params_hash["withHoldingTax"] = if permitted[:withHoldingTax].present?
                                      permitted[:withHoldingTax] == "1" || permitted[:withHoldingTax] == true || permitted[:withHoldingTax] == "true"
                                    else
                                      false
                                    end
    params_hash["isDeleted"] = false # Default to false as per spec
    
    # Convert addressesRel array - support multiple addresses
    addresses_rel = params[:company][:addressesRel]
    if addresses_rel.present? && addresses_rel.is_a?(ActionController::Parameters)
      params_hash["addressesRel"] = addresses_rel.values.map do |addr|
        {
          "addressId" => addr[:addressId].to_i,
          "addressTypeId" => addr[:addressTypeId].to_i
        }
      end.reject { |addr| addr["addressId"].zero? || addr["addressTypeId"].zero? }
    else
      params_hash["addressesRel"] = []
    end
    
    # Convert contactRel array - support multiple contacts
    contact_rel = params[:company][:contactRel]
    if contact_rel.present? && contact_rel.is_a?(ActionController::Parameters)
      params_hash["contactRel"] = contact_rel.values.map do |contact|
        {
          "contactId" => contact[:contactId].to_i,
          "jobRoleId" => contact[:jobRoleId].to_i
        }
      end.reject { |contact| contact["contactId"].zero? || contact["jobRoleId"].zero? }
    else
      params_hash["contactRel"] = []
    end
    
    params_hash
  end

  def validate_company_params(params_hash)
    errors = []
    
    # Rule: name is mandatory
    if params_hash["name"].blank?
      errors << "Name is required"
    end
    
    # Rule: If withHoldingTax = true, withHoldingTaxRate is required
    if params_hash["withHoldingTax"] == true && params_hash["withHoldingTaxRate"].blank?
      errors << "withHoldingTaxRate is required when withHoldingTax is true"
    end
    
    errors
  end

  def validate_company_params(params_hash)
    errors = []
    
    # Rule: name is mandatory
    if params_hash["name"].blank?
      errors << "Name is required"
    end
    
    # Rule: If withHoldingTax = true, withHoldingTaxRate is required
    if params_hash["withHoldingTax"] == true && params_hash["withHoldingTaxRate"].blank?
      errors << "withHoldingTaxRate is required when withHoldingTax is true"
    end
    
    errors
  end

  def fetch_companies_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_companies

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Companies: Failed to fetch companies data")
        flash.now[:error] = "Failed to fetch companies"
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      companies_array = response_data["data"] || response_data[:data] || []
      return [] unless companies_array.is_a?(Array)

      companies_array
    rescue StandardError => e
      Rails.logger.error("Companies: Error fetching companies from API: #{e.message}")
      Rails.logger.error("Companies backtrace: #{e.backtrace.first(10).join("\n")}")
      flash.now[:error] = "Error loading companies"
      []
    end
  end

  def fetch_addresses_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_addresses

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Companies: Failed to fetch addresses data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      addresses_array = response_data["data"] || response_data[:data] || []
      return [] unless addresses_array.is_a?(Array)

      addresses_array
    rescue StandardError => e
      Rails.logger.error("Companies: Error fetching addresses from API: #{e.message}")
      []
    end
  end

  def fetch_job_roles_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_job_roles

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Companies: Failed to fetch job roles data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      job_roles_array = response_data["data"] || response_data[:data] || []
      return [] unless job_roles_array.is_a?(Array)

      job_roles_array
    rescue StandardError => e
      Rails.logger.error("Companies: Error fetching job roles from API: #{e.message}")
      []
    end
  end
end




