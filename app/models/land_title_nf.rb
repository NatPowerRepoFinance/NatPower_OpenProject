class LandTitleNf < ApplicationRecord
  self.table_name = "land_titles_nf"

  belongs_to :land_parcel_nf, foreign_key: "land_parcel_id", optional: true

  validates :land_title_id, presence: true, uniqueness: true
end

