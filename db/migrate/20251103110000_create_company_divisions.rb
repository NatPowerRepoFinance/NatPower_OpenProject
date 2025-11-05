# frozen_string_literal: true

class CreateCompanyDivisions < ActiveRecord::Migration[8.0]
  def change
    create_table :company_divisions do |t|
      t.string :label, null: false
      t.string :code, null: false
      t.string :company, null: false
      t.string :company_group
      t.string :comments

      t.timestamps
    end

    add_index :company_divisions, :code, unique: true
  end
end


