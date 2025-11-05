# frozen_string_literal: true

class SeedLookupProjectStages < ActiveRecord::Migration[8.0]
  class LookupProjectStage < ApplicationRecord
    self.table_name = 'lookup_project_stages'
  end

  def up
    stages = [
      { stage_id: 0, label: 'Opportunity', comments: nil },
      { stage_id: 1, label: 'Prospect', comments: nil },
      { stage_id: 2, label: 'Preparation and Agreement', comments: nil },
      { stage_id: 3, label: 'Development and Pre-planning', comments: nil },
      { stage_id: 4, label: 'Planning and Permitting', comments: nil },
      { stage_id: 5, label: 'Ready to Build', comments: nil },
      { stage_id: 6, label: 'Construction', comments: nil },
      { stage_id: 7, label: 'Operation', comments: nil }
    ]

    LookupProjectStage.insert_all(stages, unique_by: :index_lookup_project_stages_on_stage_id)
  end

  def down
    stage_ids = [0, 1, 2, 3, 4, 5, 6, 7]
    LookupProjectStage.where(stage_id: stage_ids).delete_all
  end
end

