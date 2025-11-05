# frozen_string_literal: true

class CreateLookupProjectStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :lookup_project_statuses do |t|
      t.integer :status_id, null: false, limit: 2
      t.string :label, null: false
      t.string :comments

      t.index :status_id, unique: true
      t.index :label
    end
  end
end

