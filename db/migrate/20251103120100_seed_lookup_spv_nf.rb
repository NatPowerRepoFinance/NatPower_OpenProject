# frozen_string_literal: true

class SeedLookupSpvNf < ActiveRecord::Migration[8.0]
  def up
    spvs = [
      { spv_id: 1,  spv_name: 'NP SPV 11' },
      { spv_id: 2,  spv_name: 'NP SPV 13' },
      { spv_id: 3,  spv_name: 'NP SPV 14' },
      { spv_id: 4,  spv_name: 'NP SPV 15' },
      { spv_id: 5,  spv_name: 'NP SPV 16' },
      { spv_id: 6,  spv_name: 'NP SPV 17' },
      { spv_id: 7,  spv_name: 'NP SPV 18' },
      { spv_id: 8,  spv_name: 'NP SPV 20' },
      { spv_id: 9,  spv_name: 'NP SPV 26' },
      { spv_id: 10, spv_name: 'NP SPV 27' },
      { spv_id: 11, spv_name: 'NP SPV 29' },
      { spv_id: 12, spv_name: 'NP SPV 30' },
      { spv_id: 13, spv_name: 'NP SPV 34' },
      { spv_id: 14, spv_name: 'NP SPV 41' },
      { spv_id: 15, spv_name: 'NP SPV 42' },
      { spv_id: 16, spv_name: 'NP SPV 43' },
      { spv_id: 17, spv_name: 'NP SPV 44' },
      { spv_id: 18, spv_name: 'NP SPV 45' },
      { spv_id: 19, spv_name: 'NP SPV 46' },
      { spv_id: 20, spv_name: 'NP SPV 47' },
      { spv_id: 21, spv_name: 'NP SPV 48' },
      { spv_id: 22, spv_name: 'NP SPV 49' },
      { spv_id: 23, spv_name: 'NP SPV 50' }
    ]

    LookupSpvNf.insert_all(spvs, unique_by: :spv_id)
  end

  def down
    spv_ids = (1..23).to_a
    LookupSpvNf.where(spv_id: spv_ids).delete_all
  end
end

