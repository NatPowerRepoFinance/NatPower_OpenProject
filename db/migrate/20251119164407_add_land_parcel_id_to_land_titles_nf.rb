class AddLandParcelIdToLandTitlesNf < ActiveRecord::Migration[8.0]
  def change
    add_column :land_titles_nf, :land_parcel_id, :bigint unless column_exists?(:land_titles_nf, :land_parcel_id)
    add_index :land_titles_nf, :land_parcel_id, name: "index_land_titles_nf_on_land_parcel_id" unless index_exists?(:land_titles_nf, :land_parcel_id)
    
    add_foreign_key :land_titles_nf, :land_parcel, column: :land_parcel_id, primary_key: :id, on_delete: :cascade, on_update: :cascade unless foreign_key_exists?(:land_titles_nf, :land_parcel)
  end
end

