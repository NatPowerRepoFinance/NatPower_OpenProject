# frozen_string_literal: true

class SeedLookupProjectStatuses < ActiveRecord::Migration[8.0]
  class LookupProjectStatus < ApplicationRecord
    self.table_name = 'lookup_project_statuses'
  end

  def up
    statuses = [
      { status_id: 0, label: 'Active', comments: nil },
      { status_id: 1, label: 'On Hold', comments: nil },
      { status_id: 2, label: 'Archive', comments: nil },
      { status_id: 3, label: 'Deleted', comments: nil }
    ]

    LookupProjectStatus.insert_all(statuses, unique_by: :index_lookup_project_statuses_on_status_id)
  end

  def down
    status_ids = [0, 1, 2, 3]
    LookupProjectStatus.where(status_id: status_ids).delete_all
  end
end

