class LandContractNf < ApplicationRecord
  self.table_name = "land_contracts_nf"

  belongs_to :land_negotiation_nf, foreign_key: "land_negotiation_id", optional: true

  validates :contract_id, uniqueness: true, allow_nil: true
end

