class LandParcelNf < ApplicationRecord
  self.table_name = "land_parcel"

  belongs_to :pda_nf, foreign_key: "pda_id", optional: true
  has_many :land_titles_nfs, class_name: "LandTitleNf", foreign_key: "land_parcel_id", dependent: :destroy

  validates :land_parcel_id, presence: true, uniqueness: true
end

