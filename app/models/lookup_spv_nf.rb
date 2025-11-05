# frozen_string_literal: true

class LookupSpvNf < ApplicationRecord
  self.table_name = 'lookup_spv_nf'
  self.primary_key = 'spv_id'

  validates :spv_id, presence: true
  validates :spv_name, presence: true

  scope :ordered, -> { order(:spv_name, :spv_id) }
end

