class CreateLandNegotiationNfs < ActiveRecord::Migration[8.0]
  def change
    create_table :land_negotiation_nf do |t|
      t.string :code
      t.string :name
      t.string :friendly_name
      t.integer :contract_status
      t.integer :negotiation_status
      t.timestamp :created_date, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamp :last_updated_date
      t.timestamp :deleted_date
      t.integer :created_by
      t.integer :modified_by
      t.integer :project_id
      t.integer :pda_id
      t.bigint :land_negotiation_id
      t.string :status, default: "active"
      t.string :success_rating
      t.date :estimated_completion
      t.bigint :budget_id

      t.index :project_id, name: "index_land_negotiation_nf_on_project_id"
      t.index :pda_id, name: "index_land_negotiation_nf_on_pda_id"
      t.index :land_negotiation_id, name: "index_land_negotiation_nf_on_land_negotiation_id"
      t.index :budget_id, name: "index_land_negotiation_nf_on_budget_id"
    end

    add_foreign_key :land_negotiation_nf, :projects, column: :project_id, on_delete: :cascade, on_update: :cascade
    add_foreign_key :land_negotiation_nf, :pda_nf, column: :pda_id, primary_key: :id, on_delete: :cascade, on_update: :cascade
  end
end

