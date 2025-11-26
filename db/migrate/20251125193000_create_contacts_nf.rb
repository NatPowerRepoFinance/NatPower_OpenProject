class CreateContactsNf < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts_nf, primary_key: :contact_id do |t|
      t.integer :honorifics_id
      t.string :first_name
      t.string :last_name
      t.string :full_name
      t.string :email_work
      t.string :email_private
      t.string :phone
      t.string :mobile
      t.string :phone_alternative
      t.string :job_title
      t.date :date_of_birth
      t.boolean :is_deleted
      t.timestamp :created_date, default: -> { "CURRENT_TIMESTAMP" }
      t.integer :created_by
      t.timestamp :modified_date, default: -> { "CURRENT_TIMESTAMP" }
      t.integer :modified_by
      t.timestamp :deleted_date
    end
  end
end

