# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class CreatePdaNfs < ActiveRecord::Migration[8.0]
  def change
    create_table :pda_nf do |t|
      t.bigint :pda_id, null: false
      t.string :initial_code, null: false
      t.bigint :project_id
      t.string :code, null: false
      t.bigint :created_by
      t.timestamp :created_date, default: -> { "CURRENT_TIMESTAMP" }
      t.bigint :modified_by
      t.timestamp :modified_date, default: -> { "CURRENT_TIMESTAMP" }
      t.bigint :project_manager_guid
      t.bigint :planning_manager_guid
      t.bigint :land_manager_guid
      t.decimal :mw_bess, precision: 15, scale: 2, default: 0
      t.decimal :mw_solar, precision: 15, scale: 2, default: 0
      t.decimal :mw_wind, precision: 15, scale: 2, default: 0
      t.decimal :mw_hydrogen, precision: 15, scale: 2, default: 0
      t.decimal :mw_other, precision: 15, scale: 2, default: 0
      t.string :mw_other_description
      t.text :technology
      t.integer :senior_dev_manager_guid
      t.boolean :custom_substation
      t.boolean :transmisson_substation
      t.decimal :mw_hydroelectric, precision: 15, scale: 2

      t.index :project_id, name: "index_pda_nf_on_project_id"
      t.index :pda_id, name: "index_pda_nf_on_pda_id"
    end

    add_foreign_key :pda_nf, :projects, column: :project_id, on_delete: :cascade, on_update: :cascade
  end
end
