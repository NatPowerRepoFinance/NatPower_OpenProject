class CreateLandParcels < ActiveRecord::Migration[8.0]
  def change
    create_table :land_parcel do |t|
      t.bigint :land_parcel_id, null: false
      t.string :land_parcel_code, limit: 250
      t.bigint :pda_id

      t.index :land_parcel_id, unique: true, name: "index_land_parcel_on_land_parcel_id"
      t.index :pda_id, name: "index_land_parcel_on_pda_id"
    end
    
    add_foreign_key :land_parcel, :pda_nf, column: :pda_id, primary_key: :id, on_delete: :cascade, on_update: :cascade
  end
end

