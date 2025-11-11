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

class AddProjectDetailsFields < ActiveRecord::Migration[8.0]
  def change
    change_table :projects, bulk: true do |t|
      t.string  :project_code
      t.string  :project_financial_code, limit: 9

      t.string  :project_spv_name
      t.string  :project_site_name, limit: 50

      t.string  :project_status, null: false, default: "Active"
      # Note: project_stage stores the label string from lookup_project_stages table
      # Default matches the first seeded stage (stage_id: 0, label: "Opportunity")
      t.string  :project_stage, null: false, default: "Opportunity"
      # Note: project_division stores the code string from company_divisions table
      t.string  :project_division
      t.uuid    :project_gis_object_id
      t.uuid    :project_gis_database_id

      t.index :project_code, unique: true
      t.index :project_status
      t.index :project_stage
      t.index :project_division
    end

    change_table :project_journals, bulk: true do |t|
      t.string  :project_code
      t.string  :project_financial_code, limit: 9
      t.string  :project_spv_name
      t.string  :project_site_name, limit: 50
      t.string  :project_status
      t.string  :project_stage
      t.string  :project_division
      t.uuid    :project_gis_object_id
      t.uuid    :project_gis_database_id
    end
  end
end

