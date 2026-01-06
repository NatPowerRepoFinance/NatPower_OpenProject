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

module Companies
  class CreateService < ::BaseServices::BaseCallable
    attr_reader :user

    def initialize(user:)
      super()
      @user = user
    end

    protected

    def perform
      attributes = normalize_attributes(params)
      validation_result = validate_attributes(attributes)

      return validation_result unless validation_result.success?

      create_company(attributes)
    end

    private

    def normalize_attributes(raw_params)
      # Convert ActionController::Parameters to hash if needed
      params_hash = raw_params.is_a?(ActionController::Parameters) ? raw_params.to_h : raw_params
      params_hash = params_hash.deep_symbolize_keys if params_hash.is_a?(Hash)

      result = {}

      # Basic fields - convert to proper types and use camelCase string keys
      result["name"] = params_hash[:name].to_s.strip if params_hash[:name].present?
      result["website"] = params_hash[:website].to_s.strip if params_hash[:website].present?
      result["companyNumber"] = params_hash[:companyNumber].to_s.strip if params_hash[:companyNumber].present?
      result["taxNumber"] = params_hash[:taxNumber].to_s.strip if params_hash[:taxNumber].present?

      # Numeric fields - allow decimals
      result["vatRate"] = params_hash[:vatRate].to_f if params_hash[:vatRate].present?
      result["withHoldingTaxRate"] = params_hash[:withHoldingTaxRate].to_f if params_hash[:withHoldingTaxRate].present?
      result["paymentTerms"] = params_hash[:paymentTerms].to_i if params_hash[:paymentTerms].present?
      result["earlyPaymentDiscount"] = params_hash[:earlyPaymentDiscount].to_f if params_hash[:earlyPaymentDiscount].present?
      result["latePaymentPenalties"] = params_hash[:latePaymentPenalties].to_f if params_hash[:latePaymentPenalties].present?

      # Boolean fields
      result["withHoldingTax"] = parse_boolean(params_hash[:withHoldingTax])
      result["isDeleted"] = false # Default to false as per spec

      # Convert addressesRel array - support multiple addresses
      addresses_rel = params_hash[:addressesRel]
      if addresses_rel.present?
        addresses_array = addresses_rel.is_a?(Hash) ? addresses_rel.values : Array(addresses_rel)
        result["addressesRel"] = addresses_array.map do |addr|
          addr_hash = addr.is_a?(Hash) ? addr : addr.to_h
          {
            "addressId" => (addr_hash[:addressId] || addr_hash["addressId"]).to_i,
            "addressTypeId" => (addr_hash[:addressTypeId] || addr_hash["addressTypeId"]).to_i
          }
        end.reject { |addr| addr["addressId"].zero? || addr["addressTypeId"].zero? }
      else
        result["addressesRel"] = []
      end

      # Convert contactRel array - support multiple contacts
      contact_rel = params_hash[:contactRel]
      if contact_rel.present?
        contact_array = contact_rel.is_a?(Hash) ? contact_rel.values : Array(contact_rel)
        result["contactRel"] = contact_array.map do |contact|
          contact_hash = contact.is_a?(Hash) ? contact : contact.to_h
          {
            "contactId" => (contact_hash[:contactId] || contact_hash["contactId"]).to_i,
            "jobRoleId" => (contact_hash[:jobRoleId] || contact_hash["jobRoleId"]).to_i
          }
        end.reject { |contact| contact["contactId"].zero? || contact["jobRoleId"].zero? }
      else
        result["contactRel"] = []
      end

      result
    end

    def parse_boolean(value)
      return false if value.blank?

      value == "1" || value == true || value == "true"
    end

    def validate_attributes(attributes)
      errors = ActiveModel::Errors.new(self)

      # Rule: name is mandatory
      if attributes["name"].blank?
        errors.add(:name, :blank, message: "Name is required")
      end

      # Rule: If withHoldingTax = true, withHoldingTaxRate is required
      if attributes["withHoldingTax"] == true && attributes["withHoldingTaxRate"].blank?
        errors.add(:withHoldingTaxRate, :blank, message: "withHoldingTaxRate is required when withHoldingTax is true")
      end

      if errors.any?
        ServiceResult.failure(errors: errors, result: attributes)
      else
        ServiceResult.success(result: attributes)
      end
    end

    def create_company(attributes)
      gis_service = ::GisAPI::GisApiService.new
      result = gis_service.create_company(attributes)

      # Handle API responses according to spec:
      # 200 success, 400 validation error, 401 auth error
      if result.success?
        response_data = result.result

        # Check if API returned an error code in the response (400 validation error)
        api_error_code = response_data.is_a?(Hash) ? (response_data["code"] || response_data[:code]) : nil
        api_error_message = response_data.is_a?(Hash) ? (response_data["message"] || response_data[:message]) : nil

        # Handle 400 validation errors (API returns 200 but with error code 400 in body)
        if api_error_code.present? && api_error_code == 400
          errors = ActiveModel::Errors.new(self)
          errors.add(:base, :invalid, message: api_error_message || "Validation error: Failed to create company")
          return ServiceResult.failure(errors: errors, result: attributes)
        end

        # Success case
        ServiceResult.success(result: response_data)
      else
        # Handle API errors (401, network errors, etc.)
        errors = result.errors

        # Check for authentication errors
        error_messages = errors.respond_to?(:full_messages) ? errors.full_messages : [errors.to_s]
        if error_messages.any? { |msg| msg.include?("401") || msg.include?("auth") || msg.include?("unauthorized") }
          auth_errors = ActiveModel::Errors.new(self)
          auth_errors.add(:base, :unauthorized, message: "Authentication error: Please check your API key")
          return ServiceResult.failure(errors: auth_errors, result: attributes)
        end

        # Other errors
        ServiceResult.failure(errors: errors, result: attributes)
      end
    end
  end
end

