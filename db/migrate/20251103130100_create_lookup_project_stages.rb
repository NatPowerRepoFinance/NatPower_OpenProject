# frozen_string_literal: true

class CreateLookupProjectStages < ActiveRecord::Migration[8.0]
  def change
    create_table :lookup_project_stages do |t|
      t.integer :stage_id, null: false, limit: 2
      t.string :label, null: false
      t.string :comments

      t.index :stage_id, unique: true
      t.index :label
    end
  end
end

