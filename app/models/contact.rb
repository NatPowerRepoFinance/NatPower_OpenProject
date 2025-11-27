# frozen_string_literal: true

class Contact < ApplicationRecord
  self.table_name = "contacts_nf"
  self.primary_key = "contact_id"

  belongs_to :creator, class_name: "User", foreign_key: "created_by", optional: true
  belongs_to :modifier, class_name: "User", foreign_key: "modified_by", optional: true

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_work, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email_private, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :populate_full_name
  before_save :stamp_audit_fields

  scope :ordered_by_name, lambda {
    order(Arel.sql("COALESCE(full_name, last_name, first_name, '')"), :last_name, :first_name)
  }

  def display_name
    full_name.presence || fallback_full_name
  end

  def primary_email
    email_work.presence || email_private
  end

  private

  def populate_full_name
    assembled_name = fallback_full_name
    self.full_name = assembled_name if full_name.blank? && assembled_name.present?
  end

  def fallback_full_name
    [first_name, last_name].compact.join(" ").squish
  end

  def stamp_audit_fields
    return unless User.current

    self.modified_by = User.current.id
    self.modified_date = Time.current
    self.created_by ||= User.current.id
    self.created_date ||= Time.current
  end
end

