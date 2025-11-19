module Grids
  module Widgets
    class Pdas < Grids::WidgetComponent
      include Rails.application.routes.url_helpers
      include ERB::Util
      include ActionView::Helpers::UrlHelper

      param :project

      def initialize(...)
        super
      end

      def title
        t(".title")
      end

      def render?
        project.present?
      end

      def pda_nfs
        @pda_nfs ||= project.pda_nfs.order(created_date: :desc).to_a
      end
    end
  end
end

