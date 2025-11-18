module Projects
  module Settings
    class PdaNfsForm < ApplicationForm
      form do |f|
        # Build a pda_nf if one doesn't exist
        model.pda_nfs.build if model.pda_nfs.empty?

        f.text_field(
          name: "pda_nfs_attributes[0][pda_id]",
          label: "PDA ID",
          required: true
        )

        f.text_field(
          name: "pda_nfs_attributes[0][initial_code]",
          label: "Initial Code",
          required: true
        )

        f.text_field(
          name: "pda_nfs_attributes[0][code]",
          label: "Code",
          required: true
        )

        f.text_field(
          name: "pda_nfs_attributes[0][project_manager_guid]",
          label: "Project Manager GUID",
          required: false
        )

        f.text_field(
          name: "pda_nfs_attributes[0][planning_manager_guid]",
          label: "Planning Manager GUID",
          required: false
        )

        f.text_field(
          name: "pda_nfs_attributes[0][land_manager_guid]",
          label: "Land Manager GUID",
          required: false
        )

        f.text_field(
          name: "pda_nfs_attributes[0][senior_dev_manager_guid]",
          label: "Senior Dev Manager GUID",
          required: false
        )

        f.text_area(
          name: "pda_nfs_attributes[0][technology]",
          label: "Technology",
          required: false
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_bess]",
          label: "MW BESS",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_solar]",
          label: "MW Solar",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_wind]",
          label: "MW Wind",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_hydrogen]",
          label: "MW Hydrogen",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_hydroelectric]",
          label: "MW Hydroelectric",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_other]",
          label: "MW Other",
          required: false,
          type: "number",
          step: "0.01"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][mw_other_description]",
          label: "MW Other Description",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][custom_substation]",
          label: "Custom Substation"
        )

        f.check_box(
          name: "pda_nfs_attributes[0][transmisson_substation]",
          label: "Transmission Substation"
        )
      end
    end
  end
end
