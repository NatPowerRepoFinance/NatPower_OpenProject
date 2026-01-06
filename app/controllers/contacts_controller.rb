# frozen_string_literal: true

class ContactsController < ApplicationController
  layout "admin"

  menu_item :contacts

  before_action :require_admin
  before_action :find_contact, only: %i[show edit update destroy]

  def index
    @contacts = fetch_contacts_from_api
    # Sort by full name
    @contacts = @contacts.sort_by { |c| (c["fullName"] || c[:fullName] || "").downcase } if @contacts.is_a?(Array)
  end
  
  def show; end

  def new
    @contact = ContactFormObject.new({})
    load_lookup_data
  end

  def edit
    load_lookup_data
    # Create a ContactFormObject from the API hash for the form
    @contact_form = ContactFormObject.new(contact_hash_for_form(@contact))
  end

  def create
    # Filter out nested arrays before creating form object
    contact_form_params = contact_params.to_h.except(:addressesRel, :companiesRel, "addressesRel", "companiesRel")
    @contact = ContactFormObject.new(contact_form_params)
    load_lookup_data

    # Validate honorifics_id is present (mandatory field)
    unless @contact.honorifics_id.present?
      @contact.errors.add(:honorifics_id, "can't be blank")
      render :new, status: :unprocessable_entity
      return
    end

    # Build API payload in camelCase format
    # Convert ActionController::Parameters to hash for easier manipulation
    params_hash = contact_params.to_h.symbolize_keys
    payload = build_contact_payload(params_hash)
    
    # Log the payload for debugging
    Rails.logger.info("Contact Create Payload: #{payload.inspect}")
    Rails.logger.info("Contact Params Hash: #{params_hash.inspect}")

    # Call API to create contact
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.create_contact(payload)

    if result.respond_to?(:success?) && result.success?
      flash[:notice] = "Contact created successfully"
      redirect_to contacts_path
    else
      error_message = extract_error_message(result)
      @contact.errors.add(:base, error_message)
      flash.now[:error] = "Failed to create contact: #{error_message}"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # TODO: Implement API update endpoint when available
    flash.now[:error] = "Contact update via API not yet implemented"
    # Filter out nested arrays before creating form object
    contact_form_params = contact_params.to_h.except(:addressesRel, :companiesRel, "addressesRel", "companiesRel")
    @contact_form = ContactFormObject.new(contact_form_params)
    load_lookup_data
    render :edit, status: :unprocessable_entity
  end

  def destroy
    # TODO: Implement API delete endpoint when available
    flash[:error] = "Contact deletion via API not yet implemented"
    redirect_to contacts_path, status: :see_other
  end

  private

  def find_contact
    contacts = fetch_contacts_from_api
    contact_id = params[:id].to_i
    @contact = contacts.find { |c| (c["contactId"] || c[:contactId] || c["id"] || c[:id]).to_i == contact_id }
    
    unless @contact
      flash[:error] = "Contact not found"
      redirect_to contacts_path
    end
  end

  def fetch_contacts_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_contacts

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch contacts data")
        flash.now[:error] = "Failed to fetch contacts"
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      contacts_array = response_data["data"] || response_data[:data] || []
      return [] unless contacts_array.is_a?(Array)

      contacts_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching contacts from API: #{e.message}")
      flash.now[:error] = "Error loading contacts"
      []
    end
  end

  def contact_params
    params.require(:contact).permit(
      :honorifics_id,
      :first_name,
      :last_name,
      :full_name,
      :email_work,
      :email_private,
      :phone,
      :mobile,
      :phone_alternative,
      :job_title,
      :date_of_birth,
      :is_deleted,
      addressesRel: {},
      companiesRel: {}
    ).tap do |permitted|
      # Handle nested arrays for addressesRel
      if params[:contact][:addressesRel].present?
        permitted[:addressesRel] = params[:contact][:addressesRel].values.map do |addr|
          {
            addressId: addr[:addressId] || addr["addressId"],
            addressTypeId: addr[:addressTypeId] || addr["addressTypeId"]
          }
        end.reject { |a| a[:addressId].blank? || a[:addressTypeId].blank? }
      end

      # Handle nested arrays for companiesRel
      if params[:contact][:companiesRel].present?
        permitted[:companiesRel] = params[:contact][:companiesRel].values.map do |comp|
          {
            companyId: comp[:companyId] || comp["companyId"],
            jobRoleId: comp[:jobRoleId] || comp["jobRoleId"],
            jobTitle: comp[:jobTitle] || comp["jobTitle"]
          }
        end.reject { |c| c[:companyId].blank? || c[:jobRoleId].blank? }
      end
    end
  end

  def load_lookup_data
    @honorifics = fetch_honorifics_from_api
    @addresses = fetch_addresses_from_api
    @address_types = fetch_address_types_from_api
    @companies = fetch_companies_from_api
    @job_roles = fetch_job_roles_from_api
  end

  def fetch_honorifics_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_honorifics

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch honorifics data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      honorifics_array = response_data["data"] || response_data[:data] || []
      return [] unless honorifics_array.is_a?(Array)

      honorifics_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching honorifics from API: #{e.message}")
      []
    end
  end

  def fetch_addresses_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_addresses

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch addresses data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      addresses_array = response_data["data"] || response_data[:data] || []
      return [] unless addresses_array.is_a?(Array)

      addresses_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching addresses from API: #{e.message}")
      []
    end
  end

  def fetch_address_types_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_address_types

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch address types data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      address_types_array = response_data["data"] || response_data[:data] || []
      return [] unless address_types_array.is_a?(Array)

      address_types_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching address types from API: #{e.message}")
      []
    end
  end

  def fetch_companies_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_all_companies

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch companies data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      companies_array = response_data["data"] || response_data[:data] || []
      return [] unless companies_array.is_a?(Array)

      companies_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching companies from API: #{e.message}")
      []
    end
  end

  def fetch_job_roles_from_api
    begin
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.get_job_roles

      unless result.respond_to?(:success?) && result.success?
        Rails.logger.warn("Contacts: Failed to fetch job roles data")
        return []
      end

      response_data = result.result
      return [] unless response_data.is_a?(Hash)

      job_roles_array = response_data["data"] || response_data[:data] || []
      return [] unless job_roles_array.is_a?(Array)

      job_roles_array
    rescue StandardError => e
      Rails.logger.error("Contacts: Error fetching job roles from API: #{e.message}")
      []
    end
  end

  # Convert API hash (camelCase) to form-friendly hash (snake_case)
  def contact_hash_for_form(contact_hash)
    return {} unless contact_hash.is_a?(Hash)
    
    {
      "honorifics_id" => contact_hash["honorificsId"] || contact_hash[:honorificsId],
      "first_name" => contact_hash["firstName"] || contact_hash[:firstName],
      "last_name" => contact_hash["lastName"] || contact_hash[:lastName],
      "full_name" => contact_hash["fullName"] || contact_hash[:fullName],
      "email_work" => contact_hash["emailWork"] || contact_hash[:emailWork],
      "email_private" => contact_hash["emailPrivate"] || contact_hash[:emailPrivate],
      "phone" => contact_hash["phone"] || contact_hash[:phone],
      "mobile" => contact_hash["mobile"] || contact_hash[:mobile],
      "phone_alternative" => contact_hash["phoneAlternative"] || contact_hash[:phoneAlternative],
      "job_title" => contact_hash["jobTitle"] || contact_hash[:jobTitle],
      "date_of_birth" => contact_hash["dateOfBirth"] || contact_hash[:dateOfBirth],
      "is_deleted" => contact_hash["isDeleted"] || contact_hash[:isDeleted]
    }
  end

  def build_contact_payload(params_hash)
    # Format date_of_birth to YYYY-MM-DD format if present
    date_of_birth = if params_hash[:date_of_birth].present?
                      date_value = params_hash[:date_of_birth]
                      if date_value.is_a?(Date)
                        date_value.strftime("%Y-%m-%d")
                      elsif date_value.is_a?(String) && date_value.present?
                        # Try to parse and reformat if needed
                        begin
                          Date.parse(date_value).strftime("%Y-%m-%d")
                        rescue
                          date_value
                        end
                      else
                        nil
                      end
                    end

    # Build payload, converting empty strings to nil and ensuring proper types
    payload = {
      honorificsId: params_hash[:honorifics_id].present? ? params_hash[:honorifics_id].to_i : nil,
      firstName: params_hash[:first_name].presence,
      lastName: params_hash[:last_name].presence,
      fullName: params_hash[:full_name].presence,
      emailWork: params_hash[:email_work].presence,
      emailPrivate: params_hash[:email_private].presence,
      phone: params_hash[:phone].presence,
      mobile: params_hash[:mobile].presence,
      phoneAlternative: params_hash[:phone_alternative].presence,
      jobTitle: params_hash[:job_title].presence,
      dateOfBirth: date_of_birth,
      isDeleted: params_hash[:is_deleted].present? ? (params_hash[:is_deleted] == true || params_hash[:is_deleted] == "1" || params_hash[:is_deleted] == "true") : false
    }

    # Add addressesRel if provided
    # Handle both array format and hash format from Rails params
    addresses_rel = params_hash[:addressesRel] || params_hash["addressesRel"]
    if addresses_rel.present?
      if addresses_rel.is_a?(Array)
        payload[:addressesRel] = addresses_rel.map do |addr|
          addr_hash = addr.is_a?(Hash) ? addr : addr.to_h
          {
            addressId: (addr_hash[:addressId] || addr_hash["addressId"])&.to_i,
            addressTypeId: (addr_hash[:addressTypeId] || addr_hash["addressTypeId"])&.to_i
          }.compact
        end.reject { |a| a[:addressId].nil? || a[:addressTypeId].nil? }
      else
        payload[:addressesRel] = []
      end
    else
      payload[:addressesRel] = []
    end

    # Add companiesRel if provided
    # Handle both array format and hash format from Rails params
    companies_rel = params_hash[:companiesRel] || params_hash["companiesRel"]
    if companies_rel.present?
      if companies_rel.is_a?(Array)
        payload[:companiesRel] = companies_rel.map do |comp|
          comp_hash = comp.is_a?(Hash) ? comp : comp.to_h
          {
            companyId: (comp_hash[:companyId] || comp_hash["companyId"])&.to_i,
            jobRoleId: (comp_hash[:jobRoleId] || comp_hash["jobRoleId"])&.to_i,
            jobTitle: comp_hash[:jobTitle] || comp_hash["jobTitle"]
          }.compact
        end.reject { |c| c[:companyId].nil? || c[:jobRoleId].nil? }
      else
        payload[:companiesRel] = []
      end
    else
      payload[:companiesRel] = []
    end

    # Remove nil values to keep payload clean, but keep empty arrays
    payload.reject { |k, v| v.nil? }
  end

  def extract_error_message(result)
    if result.respond_to?(:result)
      error_data = result.result
      if error_data.is_a?(Hash)
        # Try multiple possible error message keys
        error_data["message"] || error_data[:message] || 
        error_data["error"] || error_data[:error] || 
        error_data["errors"] || error_data[:errors] ||
        "Unknown error"
      elsif error_data.is_a?(String)
        error_data
      else
        "Unknown error"
      end
    elsif result.respond_to?(:errors)
      result.errors.full_messages.join(", ")
    else
      "Failed to create contact"
    end
  end

  helper_method :contact_hash_for_form
end

# Simple object wrapper for form builder compatibility
class ContactFormObject
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :honorifics_id, :integer
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :full_name, :string
  attribute :email_work, :string
  attribute :email_private, :string
  attribute :phone, :string
  attribute :mobile, :string
  attribute :phone_alternative, :string
  attribute :job_title, :string
  attribute :date_of_birth, :date
  attribute :is_deleted, :boolean

  def initialize(attributes = {})
    super
    @errors = ActiveModel::Errors.new(self)
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "Contact")
  end
end

