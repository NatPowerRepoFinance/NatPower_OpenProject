class ProjectStatusLookup < ApplicationRecord
  self.primary_key = :id

  validates :label, presence: true
  validates :id, presence: true, uniqueness: true

  # Class methods for easy access
  def self.active
    find_by(id: 0)
  end

  def self.on_hold
    find_by(id: 1)
  end

  def self.archive
    find_by(id: 2)
  end

  def self.deleted
    find_by(id: 3)
  end

  def self.all_statuses
    order(:id)
  end
end

