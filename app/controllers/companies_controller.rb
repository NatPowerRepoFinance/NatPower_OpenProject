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
    @contacts = fetch_contacts_from_api
    @address_types = fetch_address_types_from_api
    
    respond_to do |format|
      format.html do
        render layout: "global"
      end
    end
  end

  def create
    service = ::Companies::CreateService.new(user: current_user)
    result = service.call(company_params)

    if result.success?
      flash[:notice] = "Company created successfully"
      redirect_to companies_path
    else
    @company = result.result || company_params
    @addresses = fetch_addresses_from_api
    @job_roles = fetch_job_roles_from_api
    @contacts = fetch_contacts_from_api
    @address_types = fetch_address_types_from_api
    flash.now[:error] = result.errors.full_messages.join(", ")
    render :new, status: :unprocessable_entity
    end
  end

  private

  def company_params
    params.require(:company).permit(
      :name, :website, :companyNumber, :taxNumber, :vatRate, :withHoldingTax,
      :withHoldingTaxRate, :paymentTerms, :earlyPaymentDiscount,
      :latePaymentPenalties, :isDeleted,
      addressesRel: {},
      contactRel: {}
    ).to_h.deep_symbolize_keys
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

  def fetch_contacts_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_contacts

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Companies: Failed to fetch contacts data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      contacts_array = response_data["data"] || response_data[:data] || []
      return [] unless contacts_array.is_a?(Array)

      contacts_array
    rescue StandardError => e
      Rails.logger.error("Companies: Error fetching contacts from API: #{e.message}")
      []
    end
  end

  def fetch_address_types_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_address_types

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Companies: Failed to fetch address types data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      address_types_array = response_data["data"] || response_data[:data] || []
      return [] unless address_types_array.is_a?(Array)

      address_types_array
    rescue StandardError => e
      Rails.logger.error("Companies: Error fetching address types from API: #{e.message}")
      []
    end
  end
end




