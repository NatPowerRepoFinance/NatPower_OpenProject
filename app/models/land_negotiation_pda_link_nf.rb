class LandNegotiationPdaLinkNf < ApplicationRecord
  self.table_name = "land_negotiation_pda_link_nf"

  belongs_to :land_negotiation_nf, foreign_key: "land_negotiation_id", optional: true
  belongs_to :pda_nf, foreign_key: "pda_id", optional: true

  validates :land_negotiation_id, uniqueness: { scope: :pda_id }
end

