class CreateLandNegotiationPdaLinkNfs < ActiveRecord::Migration[8.0]
  def change
    create_table :land_negotiation_pda_link_nf do |t|
      t.bigint :land_negotiation_id
      t.bigint :pda_id

      t.index :land_negotiation_id, name: "index_land_negotiation_pda_link_nf_on_land_negotiation_id"
      t.index :pda_id, name: "index_land_negotiation_pda_link_nf_on_pda_id"
      t.index [:land_negotiation_id, :pda_id], unique: true, name: "index_land_negotiation_pda_link_nf_unique"
    end
    
    add_foreign_key :land_negotiation_pda_link_nf, :land_negotiation_nf, column: :land_negotiation_id, primary_key: :id, on_delete: :cascade, on_update: :cascade
    add_foreign_key :land_negotiation_pda_link_nf, :pda_nf, column: :pda_id, primary_key: :id, on_delete: :cascade, on_update: :cascade
  end
end

