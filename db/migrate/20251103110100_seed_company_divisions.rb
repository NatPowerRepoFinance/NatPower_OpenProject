# frozen_string_literal: true

class SeedCompanyDivisions < ActiveRecord::Migration[8.0]
  class CompanyDivision < ApplicationRecord
    self.table_name = 'company_divisions'
  end

  def up
    now = Time.current
    divisions = [
      { label: 'NatPower UK Onshore',       code: 'NPLUK', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower Uk Marine',        code: 'NPMUK', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower UK Hydrogen',      code: 'NPHUK', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower IT Onshore',       code: 'NPLIT', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower IT Marine',        code: 'NPMIT', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower IT Hydrogen',      code: 'NPHIT', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'NatPower Kazakhstan Hydro', code: 'NPDKZ', company: 'NatPower',         company_group: nil, comments: nil },
      { label: 'WK NatPower Hong Kong',     code: 'WKMHK', company: 'WK NatPower JV',   company_group: 'WK', comments: nil }
    ].map { |h| h.merge(created_at: now, updated_at: now) }

    CompanyDivision.insert_all(divisions, unique_by: :index_company_divisions_on_code)
  end

  def down
    codes = %w[NPLUK NPMUK NPHUK NPLIT NPMIT NPHIT NPDKZ WKMHK]
    CompanyDivision.where(code: codes).delete_all
  end
end


