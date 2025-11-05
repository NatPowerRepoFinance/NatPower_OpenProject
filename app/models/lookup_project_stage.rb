# frozen_string_literal: true

class LookupProjectStage < ApplicationRecord
  self.table_name = 'lookup_project_stages'
  self.primary_key = 'stage_id'

  validates :stage_id, presence: true
  validates :label, presence: true

  scope :ordered, -> { order(:stage_id) }
end

