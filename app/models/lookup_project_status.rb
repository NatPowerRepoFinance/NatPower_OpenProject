# frozen_string_literal: true

class LookupProjectStatus < ApplicationRecord
  self.table_name = 'lookup_project_statuses'
  self.primary_key = 'status_id'

  validates :status_id, presence: true
  validates :label, presence: true

  scope :ordered, -> { order(:status_id) }
end

