module Grids
  module Widgets
    class Pdas < Grids::WidgetComponent
      include Rails.application.routes.url_helpers
      include ERB::Util
      include ActionView::Helpers::UrlHelper

      param :project

      def initialize(...)
        super
        @pdas = nil
      end

      def title
        t(".title")
      end

      def render?
        project.present?
      end

      # Fetch PDAs from the API cluster endpoint
      # Returns array of PDAs with name and id
      # Always returns an array, never nil
      def pdas
        return @pdas if defined?(@pdas) && @pdas.is_a?(Array)

        @pdas = fetch_pdas_from_api
        @pdas = [] unless @pdas.is_a?(Array)
        @pdas
      end

      # Get the PDA database record for a given API PDA id
      # Returns the PdaNf record if found, nil otherwise
      def pda_record(pda_id)
        return nil unless project.present? && pda_id.present?
        return nil unless project.respond_to?(:pda_nfs)

        @pda_records ||= {}
        @pda_records[pda_id] ||= project.pda_nfs.find_by(pda_id: pda_id.to_i)
      end

      # Get the URL for a PDA show page
      # Uses by_pda_id route which works even if PDA doesn't exist in database
      def pda_path(pda_id)
        return nil unless project.present? && pda_id.present?

        by_pda_id_project_settings_pda_nfs_path(project, pda_id: pda_id)
      end

      private

      def fetch_pdas_from_api
        return [] unless project.present?

        # Get project ID - works for both database projects and API adapter projects
        project_id = project.respond_to?(:id) ? project.id : nil
        return [] unless project_id.present?

        begin
          gis_service = ::GisAPI::GisApiService.new
          result = gis_service.get_cluster(project_id)


          unless result.respond_to?(:success?) && result.success?
            Rails.logger.warn("PDAs Widget: Failed to fetch cluster data for project #{project_id}")
            return []
          end

          cluster_data = result.result
          
          return [] unless cluster_data.is_a?(Hash)

          

          # Extract features array from cluster data
          # Features are PDAs in the cluster response
          features = cluster_data.dig("data").dig("cluster").dig("features") || []
          
          return [] unless features.is_a?(Array)

          # Map features to PDAs with name and id from properties
          pdas_array = features.filter_map do |feature|
            next unless feature.is_a?(Hash)

            properties = feature["properties"] || feature[:properties] || {}
            next if properties.empty?

            pda_id = properties["id"] || properties[:id]
            pda_name = properties["name"] || properties[:name]
            status = properties["status"] || properties[:status]

            # Only include PDAs that have at least an id or name
            if pda_id.present? || pda_name.present?
              {
                id: pda_id,
                name: pda_name,
                status: status
              }
            end
          end

          # Ensure we return an array
          Array(pdas_array)
        rescue StandardError => e
          Rails.logger.error("PDAs Widget: Error fetching PDAs from API: #{e.message}")
          Rails.logger.error("PDAs Widget backtrace: #{e.backtrace.first(10).join("\n")}")
          []
        end
      end
    end
  end
end

