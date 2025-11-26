class CreateLandTitlesNfs < ActiveRecord::Migration[8.0]
  def change
    create_table :land_titles_nf do |t|
      t.string :land_title_id, null: false, limit: 255
      t.string :land_registry_title_id, limit: 20
      t.bigint :land_registry_id
      t.string :land_registry_title_document_link, limit: 100
      t.date :land_registry_title_request_date

      t.index :land_registry_id, name: "index_land_titles_nf_on_land_registry_id"
      t.index :land_title_id, unique: true, name: "index_land_titles_nf_on_land_title_id"
    end
  end
end

