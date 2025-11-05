# frozen_string_literal: true

class CreateLookupSpvNf < ActiveRecord::Migration[8.0]
  def change
    create_table :lookup_spv_nf do |t|
      t.integer :spv_id, null: false
      t.string :spv_name

      t.index :spv_id, unique: true
    end
  end
end
