# frozen_string_literal: true

class CompanyDivision < ApplicationRecord
  validates :label, :code, :company, presence: true
  validates :code, uniqueness: true

  scope :ordered, -> { order(:label, :code) }
end


