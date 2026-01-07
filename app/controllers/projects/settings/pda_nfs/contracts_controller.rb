require "ostruct"
require "securerandom"

class Projects::Settings::PdaNfs::ContractsController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[new create]
  before_action :find_pda_nf_and_negotiation

  def new
    @contract_form = default_contract_form(nil, nil)
    fetch_contract_statuses
  end

  def create
    form_params = contract_form_params
    # Extract file from params separately - file uploads are not included in permitted params
    uploaded_file = params.dig(:contract, :contractDocument)
    Rails.logger.info("[PDA Contracts] File upload present: #{uploaded_file.present?}, filename: #{uploaded_file&.original_filename}")
    
    @contract_form = default_contract_form(nil, nil)
    @contract_form.merge!(form_params.to_h)
    
    # Re-fetch statuses for the form in case of errors
    fetch_contract_statuses

    unless api_key.present?
      flash.now[:error] = "Missing GIS API key. Please configure GIS_API_KEY and try again."
      return render :new, status: :unprocessable_entity
    end

    %w[landNegotiationId pdaId projectId].each do |required_key|
      next if @contract_form[required_key].present?

      flash.now[:error] = "#{required_key} is required to create a contract."
      return render :new, status: :unprocessable_entity
    end

    Rails.logger.info("[PDA Contracts] Preparing contract request for negotiation=#{@contract_form["landNegotiationId"]} pda=#{@contract_form["pdaId"]} file=#{uploaded_file.present? ? uploaded_file.original_filename : 'none'}")
    response = submit_contract_creation_request(@contract_form, uploaded_file)

    if response && response.status == 200
      flash[:notice] = "Contract request submitted to the GIS API."
      redirect_to negotiation_by_pda_id_project_settings_pda_nfs_path(@project, pda_id: @pda_id, negotiation_id: @api_negotiation_id)
    else
      error_message = response ? "API responded with status #{response.status} #{extract_api_error(response)}" : "Request failed before reaching the API"
      flash.now[:error] = "Unable to create contract via API. #{error_message}."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_pda_nf_and_negotiation
    # API-only mode - just use params directly, no database
    @pda_id = params[:pda_id] || params[:pda_nf_id]
    
    unless @pda_id.present?
      flash[:error] = "PDA ID is required"
      redirect_to project_settings_pda_nfs_path(@project)
      return
    end

    negotiation_identifier = params[:negotiation_id]
    @land_negotiation = build_virtual_negotiation_from_params(negotiation_identifier)
    @api_negotiation_id = params[:api_negotiation_id].presence || negotiation_identifier
  end

  def build_virtual_negotiation_from_params(identifier)
    OpenStruct.new(
      id: nil,
      land_negotiation_id: identifier,
      code: params[:negotiation_code],
      name: params[:negotiation_name],
      friendly_name: params[:negotiation_friendly_name],
      project_id: @project.id
    )
  end

  def contract_form_params
    params.fetch(:contract, {}).permit(
      :landNegotiationId,
      :contractDescription,
      :contractTypeId,
      :startDate,
      :completionDate,
      :status,
      :initialExpiryDate,
      :initialExpiryNoticePeriodDays,
      :extensionPeriod,
      :longStopDate,
      :pdaId,
      :projectId,
      :contractDocument
    )
  end

  def default_contract_form(pda_nf, land_negotiation)
    {
      "landNegotiationId" => @api_negotiation_id,
      "pdaId" => @pda_id,
      "projectId" => @project.id,
      # The ERP API expects the numeric status ID, not the label.
      # Default to 1 (e.g., ACTIVE) – this can be overridden in the form.
      "status" => 1
    }
  end

  def submit_contract_creation_request(form_values, uploaded_file)
    payload = normalize_contract_payload(form_values)

    body, content_type = build_request_body(payload, uploaded_file)
    return nil unless body.present?

    url = "https://natpower-gis-project-dev.azurewebsites.net/erp/contract/create"
    file_info = if uploaded_file.present?
      if uploaded_file.respond_to?(:original_filename)
        "#{uploaded_file.original_filename} (#{uploaded_file.respond_to?(:size) ? uploaded_file.size : 'unknown size'})"
      else
        "present but invalid: #{uploaded_file.class}"
      end
    else
      "none"
    end
    Rails.logger.info("[PDA Contracts] POST #{url} content_type=#{content_type} payload={request: #{payload}} file=#{file_info} body_size=#{body.bytesize}")
    OpenProject.httpx.with(
      headers: {
        "X-Access-Token" => api_key,
        "Content-Type" => content_type
      }
    ).post(url, body: body).tap do |response|
      Rails.logger.info("[PDA Contracts] Response status=#{response.status}")
    end
  rescue StandardError => e
    Rails.logger.error("Failed to create negotiation contract via API: #{e.message}")
    Rails.logger.error("Contract API backtrace: #{e.backtrace.first(5).join("\n")}")
    nil
  end

  def normalize_contract_payload(form_values)
    values = form_values.to_h.with_indifferent_access

    payload = values.transform_values { |value| value.is_a?(String) ? value.strip : value }
                    .reject { |_, value| value.blank? }

    integer_keys = %w[
      landNegotiationId
      pdaId
      projectId
      status
      contractTypeId
      initialExpiryNoticePeriodDays
      extensionPeriod
    ]

    integer_keys.each do |key|
      raw = payload[key]
      next if raw.nil?
      if raw.is_a?(String) && raw.match?(/\A-?\d+\z/)
        payload[key] = raw.to_i
      end
    end

    # Format date fields to ISO 8601 with Z timezone
    date_keys = %w[startDate completionDate initialExpiryDate longStopDate]
    date_keys.each do |key|
      raw = payload[key]
      next if raw.nil?

      if raw.is_a?(String)
        begin
          # Parse the datetime string and format as ISO 8601 with Z timezone
          datetime = Time.parse(raw)
          payload[key] = datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        rescue ArgumentError, TypeError
          # If parsing fails, keep the original value
          Rails.logger.warn("Failed to parse date for #{key}: #{raw}")
        end
      end
    end

    payload
  end

  def fetch_contract_statuses
    gis_service = ::GisAPI::GisApiService.new
    result = gis_service.get_contract_status_lookup
    
    @contract_statuses = []
    if result.respond_to?(:success?) && result.success?
      status_data = result.result
      # Handle API response format: { "code": 200, "message": null, "data": [...] }
      raw_data = if status_data.is_a?(Hash) && status_data["data"].is_a?(Array)
                   status_data["data"]
                 elsif status_data.is_a?(Array)
                   status_data
                 else
                   []
                 end
      
      @contract_statuses = raw_data.map do |status|
        {
          id: status["id"] || status[:id],
          label: status["contractStatus"] || status[:contractStatus] || status["contract_status"] || status[:contract_status]
        }
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to fetch contract statuses: #{e.message}")
    @contract_statuses = []
  end

  def extract_api_error(response)
    body = response&.to_s
    return "" unless body.present?

    begin
      json = JSON.parse(body)
      detail = json["message"] || json["error"] || json["detail"]
      return "- #{detail}" if detail.present?
    rescue JSON::ParserError
    
    end

    snippet = body.strip
    snippet.present? ? "- #{snippet}" : ""
  end

  def build_request_body(payload, uploaded_file)
    boundary = "----OpenProjectContract#{SecureRandom.hex(12)}"
    body = +""

    body << "--#{boundary}\r\n"
    body << %(Content-Disposition: form-data; name="request"\r\n)
    body << %(Content-Type: application/json\r\n\r\n)
    body << payload.to_json
    body << "\r\n"

    if uploaded_file.present? && uploaded_file.respond_to?(:tempfile)
      begin
        uploaded_file.tempfile.binmode
        uploaded_file.rewind
        file_content = uploaded_file.read
        uploaded_file.rewind # Reset for potential retry
        
        body << "--#{boundary}\r\n"
        body << %(Content-Disposition: form-data; name="file"; filename="#{uploaded_file.original_filename}"\r\n)
        body << "Content-Type: #{uploaded_file.content_type || 'application/octet-stream'}\r\n\r\n"
        body << file_content
        body << "\r\n"
        
        Rails.logger.info("[PDA Contracts] File attached: #{uploaded_file.original_filename}, size: #{file_content.bytesize} bytes")
      rescue StandardError => e
        Rails.logger.error("[PDA Contracts] Error reading file: #{e.message}")
        raise
      end
    elsif uploaded_file.present?
      Rails.logger.warn("[PDA Contracts] File present but not a valid upload object: #{uploaded_file.class}")
    end

    body << "--#{boundary}--\r\n"
    [body, "multipart/form-data; boundary=#{boundary}"]
  rescue StandardError => e
    Rails.logger.error("Failed to build request body for contract API: #{e.message}")
    [nil, nil]
  ensure
    uploaded_file&.rewind
  end
end




