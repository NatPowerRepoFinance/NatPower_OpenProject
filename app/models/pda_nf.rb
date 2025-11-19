class PdaNf < ApplicationRecord
  self.table_name = "pda_nf"

  belongs_to :project, optional: true
  belongs_to :creator, class_name: "User", foreign_key: "created_by", optional: true
  belongs_to :modifier, class_name: "User", foreign_key: "modified_by", optional: true

  validates :pda_id, presence: true
  validates :initial_code, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 255 }

  scope :for_project, ->(project) { where(project_id: project.id) }

  before_save :set_modified_fields

  private

  def set_modified_fields
    self.modified_by = User.current&.id if User.current
    self.modified_date = Time.current
    self.created_by = User.current&.id if created_by.nil? && User.current
    self.created_date = Time.current if created_date.nil?
  end
end
