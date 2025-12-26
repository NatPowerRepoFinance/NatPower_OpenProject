module Grids
  module Widgets
    class ProjectCommentary < Grids::WidgetComponent
      param :project

      def initialize(...)
        super
        @commentary_data = nil
      end

      def title
        t(".title", default: "Project Commentary")
      end

      def render?
        project.present?
      end

      def commentary_items
        return @commentary_data if defined?(@commentary_data) && @commentary_data.is_a?(Array)

        @commentary_data = fetch_commentary_from_api
        @commentary_data = [] unless @commentary_data.is_a?(Array)
        @commentary_data
      end

      def format_comment_date(date_string)
        return "" unless date_string.present?

        begin
          date = Date.parse(date_string)
          date.strftime("%B %d, %Y")
        rescue
          date_string.to_s
        end
      end

      def rating_label(rating)
        case rating
        when 1
          "Positive"
        when 2
          "Neutral"
        when 3
          "Negative"
        else
          "Unknown"
        end
      end

      def rating_badge_scheme(rating)
        case rating
        when 1
          :success
        when 2
          :default
        when 3
          :danger
        else
          :default
        end
      end

      private

      def fetch_commentary_from_api
        return [] unless project.present?

        project_id = project.respond_to?(:id) ? project.id : nil
        return [] unless project_id.present?

        begin
          gis_service = ::GisAPI::GisApiService.new
          result = gis_service.get_project_commentary(project_id)

          unless result.respond_to?(:success?) && result.success?
            Rails.logger.warn("Project Commentary Widget: Failed to fetch commentary data for project #{project_id}")
            return []
          end

          response_data = result.result
          return [] unless response_data.is_a?(Hash)

          commentary_array = response_data["data"] || response_data[:data] || []
          return [] unless commentary_array.is_a?(Array)

          commentary_array.sort_by do |item|
            date_str = item["commentDate"] || item[:commentDate] || item["createdDate"] || item[:createdDate] || ""
            begin
              Date.parse(date_str)
            rescue
              Date.new(1900, 1, 1)
            end
          end.reverse
        rescue StandardError => e
          Rails.logger.error("Project Commentary Widget: Error fetching commentary from API: #{e.message}")
          Rails.logger.error("Project Commentary Widget backtrace: #{e.backtrace.first(10).join("\n")}")
          []
        end
      end
    end
  end
end

