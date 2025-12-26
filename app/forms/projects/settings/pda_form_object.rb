module Projects
  module Settings
    class PdaFormObject
      include ActiveModel::Model

      attr_accessor :initial_code, :code, :project_manager_guid, :planning_manager_guid,
                    :land_manager_guid, :senior_dev_manager_guid, :technology, :mw_bess, :mw_solar,
                    :mw_wind, :mw_hydrogen, :mw_other, :mw_other_description, :mw_hydroelectric,
                    :custom_substation, :transmisson_substation, :status_code, :spv_id

      def self.model_name
        ActiveModel::Name.new(self, nil, "PdaNf")
      end
    end
  end
end


