require "ostruct"
require "securerandom"

class Projects::Settings::PdaNfs::ContractsController < Projects::Settings::PdaNfsController
  skip_before_action :authorize, only: %i[new create]
  before_action :find_pda_nf_and_negotiation

  def new
    @contract_form = default_contract_form(@pda_nf, @land_negotiation)
  end

  def create
    form_params = contract_form_params
    uploaded_file = form_params.delete(:contractDocument)
    @contract_form = default_contract_form(@pda_nf, @land_negotiation)
    @contract_form.merge!(form_params.to_h)

    unless api_key.present?
      flash.now[:error] = "Missing GIS API key. Please configure GIS_API_KEY and try again."
      return render :new, status: :unprocessable_entity
    end

    %w[landNegotiationId pdaId projectId].each do |required_key|
      next if @contract_form[required_key].present?

      flash.now[:error] = "#{required_key} is required to create a contract."
      return render :new, status: :unprocessable_entity
    end

    Rails.logger.info("[PDA Contracts] Preparing contract request for negotiation=#{@contract_form["landNegotiationId"]} pda=#{@contract_form["pdaId"]}")
    response = submit_contract_creation_request(@contract_form, uploaded_file)

    if response && response.status == 200
      flash[:notice] = "Contract request submitted to the GIS API."
      redirect_to project_settings_pda_nf_path(@project, @pda_nf)
    else
      error_message = response ? "API responded with status #{response.status} #{extract_api_error(response)}" : "Request failed before reaching the API"
      flash.now[:error] = "Unable to create contract via API. #{error_message}."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_pda_nf_and_negotiation
    @pda_nf = @project.pda_nfs.find(params[:pda_nf_id])
    negotiation_identifier = params[:negotiation_id]

    @land_negotiation =
      @pda_nf.land_negotiation_nfs.find_by(id: negotiation_identifier) ||
      @pda_nf.land_negotiation_nfs.find_by(land_negotiation_id: negotiation_identifier) ||
      build_virtual_negotiation_from_params(negotiation_identifier)

    @api_negotiation_id = params[:api_negotiation_id].presence ||
                          @land_negotiation.try(:land_negotiation_id) ||
                          negotiation_identifier
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
      "landNegotiationId" => @api_negotiation_id || land_negotiation.land_negotiation_id || land_negotiation.id,
      "pdaId" => pda_nf.pda_id || pda_nf.id,
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
    Rails.logger.info("[PDA Contracts] POST #{url} content_type=#{content_type} payload={request: #{payload}} file=#{uploaded_file.present? ? uploaded_file.original_filename : 'none'}")
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

    payload
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
    body << %(Content-Disposition: form-data; name="request"\r\n\r\n)
    body << payload.to_json
    body << "\r\n"

    if uploaded_file.present?
      uploaded_file.tempfile.binmode
      uploaded_file.rewind
      body << "--#{boundary}\r\n"
      body << %(Content-Disposition: form-data; name="file"; filename="#{uploaded_file.original_filename}"\r\n)
      body << "Content-Type: #{uploaded_file.content_type || 'application/octet-stream'}\r\n\r\n"
      body << uploaded_file.read
      body << "\r\n"
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




