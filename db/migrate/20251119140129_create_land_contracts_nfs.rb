class CreateLandContractsNfs < ActiveRecord::Migration[8.0]
  def change
    create_table :land_contracts_nf do |t|
      t.bigint :contract_id
      t.integer :land_negotiation_id
      t.integer :contract_type_id, limit: 2
      t.date :start_date
      t.date :completion_date
      t.string :status
      t.date :initial_expiry_date
      t.integer :initial_expiry_notice_period_days
      t.integer :extension_period
      t.date :long_stop_date
      t.string :contract_document_link
      t.string :contract_description

      t.index :land_negotiation_id, name: "index_land_contracts_nf_on_land_negotiation_id"
      t.index :contract_id, name: "index_land_contracts_nf_on_contract_id"
      t.index :contract_type_id, name: "index_land_contracts_nf_on_contract_type_id"
    end
    
    add_foreign_key :land_contracts_nf, :land_negotiation_nf, column: :land_negotiation_id, primary_key: :id, on_delete: :cascade, on_update: :cascade
  end
end

