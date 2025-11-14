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

class CreateProjectStatusLookups < ActiveRecord::Migration[8.0]
  def change
    create_table :project_status_lookups, id: false do |t|
      t.integer :id, primary_key: true
      t.string :label, null: false
      t.text :comments

      t.timestamps
    end

    # Change status column from string to integer and add foreign key
    if column_exists?(:projects, :status)
      # Convert string status to integer (handle NULL and empty strings)
      execute <<-SQL
        UPDATE projects SET status = NULL WHERE status IS NULL OR status = '';
        ALTER TABLE projects ALTER COLUMN status TYPE integer USING CASE 
          WHEN status ~ '^[0-9]+$' THEN status::integer 
          ELSE NULL 
        END;
      SQL
      
      add_foreign_key :projects, :project_status_lookups, column: :status, primary_key: :id, on_delete: :restrict
    else
      add_column :projects, :status, :integer
      add_foreign_key :projects, :project_status_lookups, column: :status, primary_key: :id, on_delete: :restrict
    end

    # Insert initial data
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO project_status_lookups (id, label, comments, created_at, updated_at) VALUES
          (0, 'Active', NULL, NOW(), NOW()),
          (1, 'On Hold', NULL, NOW(), NOW()),
          (2, 'Archive', NULL, NOW(), NOW()),
          (3, 'Deleted', NULL, NOW(), NOW());
        SQL
      end
    end
  end
end

