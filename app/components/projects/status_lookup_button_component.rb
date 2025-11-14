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
    user.allowed_in_project?(:edit_project, project)
  end

  def build_items
    ProjectStatusLookup.all_statuses.map { build_item(it) }
  end

  def build_item(status_lookup)
    OpPrimer::StatusButtonOption.new(
      name: status_lookup.label,
      color_namespace: :project_status,
      color_ref: status_lookup.id.to_s,
      icon: status_icon(status_lookup.id),
      item_id: status_lookup.id,
      tag: :a,
      href: project_widgets_project_status_path(project, project: { status: status_lookup.id }),
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
        href: project_widgets_project_status_path(project, project: { status: nil }),
        content_arguments: {
          data: { turbo_method: :put, turbo: true },
          aria: { current: true }
        }
      )
    end
  end
end

