module Projects
  module Settings
    class LandNegotiationFormObject
      include ActiveModel::Model

      attr_accessor :project_id, :pda_id, :name, :friendly_name, :created_by, :negotiation_status, :success_rating, :estimated_completion

      def self.model_name
        ActiveModel::Name.new(self, nil, "LandNegotiation")
      end
    end
  end
end

