module Grids
  module Widgets
    class ProjectJournal < Grids::WidgetComponent
      param :project

      def initialize(...)
        super
        @journal_data = nil
      end

      def title
        t(".title", default: "Project Journal")
      end

      def render?
        project.present?
      end

      def journal_items
        return @journal_data if defined?(@journal_data) && @journal_data.is_a?(Array)

        @journal_data = fetch_journal_from_api
        @journal_data = [] unless @journal_data.is_a?(Array)
        @journal_data
      end

      def format_journal_date(date_string)
        return "" unless date_string.present?

        begin
          date = DateTime.parse(date_string)
          date.strftime("%B %d, %Y at %I:%M %p")
        rescue
          date_string.to_s
        end
      end

      private

      def fetch_journal_from_api
        return [] unless project.present?

        project_id = project.respond_to?(:id) ? project.id : nil
        return [] unless project_id.present?

        begin
          gis_service = ::GisAPI::GisApiService.new
          result = gis_service.get_project_journal(project_id)

          unless result.respond_to?(:success?) && result.success?
            Rails.logger.warn("Project Journal Widget: Failed to fetch journal data for project #{project_id}")
            return []
          end

          response_data = result.result
          return [] unless response_data.is_a?(Hash)

          journal_array = response_data["data"] || response_data[:data] || []
          return [] unless journal_array.is_a?(Array)

          journal_array.sort_by do |item|
            date_str = item["createdDate"] || item[:createdDate] || item["date"] || item[:date] || item["journalDate"] || item[:journalDate] || ""
            begin
              DateTime.parse(date_str)
            rescue
              DateTime.new(1900, 1, 1)
            end
          end.reverse
        rescue StandardError => e
          Rails.logger.error("Project Journal Widget: Error fetching journal from API: #{e.message}")
          Rails.logger.error("Project Journal Widget backtrace: #{e.backtrace.first(10).join("\n")}")
          []
        end
      end
    end
  end
end

