class LandNegotiationNf < ApplicationRecord
  self.table_name = "land_negotiation_nf"

  belongs_to :project, optional: true
  belongs_to :pda_nf, foreign_key: "pda_id", optional: true
  belongs_to :creator, class_name: "User", foreign_key: "created_by", optional: true
  belongs_to :modifier, class_name: "User", foreign_key: "modified_by", optional: true

  has_many :land_contracts_nfs, class_name: "LandContractNf", foreign_key: "land_negotiation_id", dependent: :destroy
  has_many :land_negotiation_pda_link_nfs, class_name: "LandNegotiationPdaLinkNf", foreign_key: "land_negotiation_id", dependent: :destroy
  has_many :linked_pdas, through: :land_negotiation_pda_link_nfs, source: :pda_nf

  scope :for_project, ->(project) { where(project_id: project.id) }
  scope :for_pda, ->(pda_id) { where(pda_id: pda_id) }
  scope :active, -> { where(status: "active") }

  before_save :set_modified_fields

  private

  def set_modified_fields
    self.modified_by = User.current&.id if User.current
    self.last_updated_date = Time.current
    self.created_by = User.current&.id if created_by.nil? && User.current
    self.created_date = Time.current if created_date.nil?
  end
end

