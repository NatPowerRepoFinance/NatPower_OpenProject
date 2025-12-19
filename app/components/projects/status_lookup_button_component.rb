class Projects::StatusLookupButtonComponent < ApplicationComponent
  include ApplicationHelper
  include OpTurbo::Streamable
  include OpPrimer::ComponentHelpers

  attr_reader :project, :user, :hide_help_text
  alias :hide_help_text? :hide_help_text

  def initialize(project:, user:, size: :medium, hide_help_text: false)
    super

    @project = project
    @user = user
    @size = size
    @hide_help_text = hide_help_text

    @current_status = project.project_status_lookup
  end

  private

  def edit_enabled?
    # Disable editing if project doesn't have a valid ID
    return false unless project_id_for_routes.present?
    
    user.allowed_in_project?(:edit_project, project)
  end

  def project_id_for_routes
    @project_id_for_routes ||= begin
      return nil unless project.present?
      
      # Handle ExternalApiProjectAdapter
      if project.is_a?(::API::V3::Projects::ExternalApiProjectAdapter)
        project_id = project.id
        return project_id.to_s if project_id.present?
        return nil
      end
      
      # Handle regular Project models
      if project.respond_to?(:to_param)
        project_id = project.to_param
        return project_id.to_s if project_id.present?
      end
      
      if project.respond_to?(:id)
        project_id = project.id
        return project_id.to_s if project_id.present?
      end
      
      nil
    end
  end

  def build_items
    # Skip building items if project doesn't have a valid ID
    return [] unless project_id_for_routes.present?
    
    ProjectStatusLookup.all_statuses.map { build_item(it) }.compact
  end

  def build_item(status_lookup)
    project_id = project_id_for_routes
    return nil unless project_id.present?
    
    OpPrimer::StatusButtonOption.new(
      name: status_lookup.label,
      color_namespace: :project_status,
      color_ref: status_lookup.id.to_s,
      icon: status_icon(status_lookup.id),
      item_id: status_lookup.id,
      tag: :a,
      href: project_widgets_project_status_path(project_id, project: { status: status_lookup.id }),
      content_arguments: {
        data: { turbo_method: :put, turbo: true },
        aria: { current: (true if status_lookup == @current_status) }
      }
    )
  end

  def status_icon(status_id)
    case status_id
    when 0
      "issue-opened" # Active
    when 1
      "clock" # On Hold
    when 2
      "archive" # Archive
    when 3
      "trash" # Deleted
    else
      "issue-draft"
    end
  end

  def current_status_item
    project_id = project_id_for_routes
    
    # If no valid project ID, return a read-only default status
    unless project_id.present?
      return OpPrimer::StatusButtonOption.new(
        name: t("placeholders.default"),
        color_namespace: :project_status,
        color_ref: "not_set",
        icon: "issue-draft",
        item_id: nil,
        tag: :span,
        href: nil,
        content_arguments: {}
      )
    end
    
    if @current_status
      build_item(@current_status)
    else
      OpPrimer::StatusButtonOption.new(
        name: t("placeholders.default"),
        color_namespace: :project_status,
        color_ref: "not_set",
        icon: "issue-draft",
        item_id: nil,
        tag: :a,
        href: project_widgets_project_status_path(project_id, project: { status: nil }),
        content_arguments: {
          data: { turbo_method: :put, turbo: true },
          aria: { current: true }
        }
      )
    end
  end
end

