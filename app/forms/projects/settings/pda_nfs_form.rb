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

        f.text_field(
          name: "pda_nfs_attributes[0][initial_name]",
          label: "Initial Name",
          required: false
        )

        f.select_list(
          name: "pda_nfs_attributes[0][status_code]",
          label: "Status Code",
          required: false,
          include_blank: true
        ) do |select|
          GisProjectLookup.all_statuses.each do |status|
            select.option(
              label: "#{status[:code]} - #{status[:description]}",
              value: status[:code]
            )
          end
        end

        f.check_box(
          name: "pda_nfs_attributes[0][has_project_start_date]",
          label: "Set Project Start Date"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][project_start_date]",
          label: "Project Start Date",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_grid_application_submitted]",
          label: "Set Grid Application Submitted"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][grid_application_submitted]",
          label: "Grid Application Submitted",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_planning_submission]",
          label: "Set Planning Submission"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][planning_submission]",
          label: "Planning Submission",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_planning_determination]",
          label: "Set Planning Determination"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][planning_determination]",
          label: "Planning Determination",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_ready_to_build]",
          label: "Set Ready to Build"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][ready_to_build]",
          label: "Ready to Build",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_grid_connection]",
          label: "Set Grid Connection"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][grid_connection]",
          label: "Grid Connection",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_cod]",
          label: "Set COD"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][cod]",
          label: "COD",
          type: "date",
          required: false
        )

        f.text_field(
          name: "pda_nfs_attributes[0][spv_id]",
          label: "SPV ID",
          required: false,
          type: "number"
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_hots_date]",
          label: "Set HOTS Date"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][hots_date]",
          label: "HOTS Date",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_land_contracts_exchaged]",
          label: "Set Land Contracts Exchanged"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][land_contracts_exchaged]",
          label: "Land Contracts Exchanged",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_grid_offer_accepted_signed]",
          label: "Set Grid Offer Accepted Signed"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][grid_offer_accepted_signed]",
          label: "Grid Offer Accepted Signed",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_np_uk_envisaged_rev_date]",
          label: "Set NP UK Envisaged Rev Date"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][np_uk_envisaged_rev_date]",
          label: "NP UK Envisaged Rev Date",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_public_consultation]",
          label: "Set Public Consultation"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][public_consultation]",
          label: "Public Consultation",
          type: "date",
          required: false
        )

        f.check_box(
          name: "pda_nfs_attributes[0][has_planning_condition_discharged]",
          label: "Set Planning Condition Discharged"
        )

        f.text_field(
          name: "pda_nfs_attributes[0][planning_condition_discharged]",
          label: "Planning Condition Discharged",
          type: "date",
          required: false
        )

        f.select_list(
          name: "pda_nfs_attributes[0][stage_code]",
          label: "Stage Code",
          required: false,
          include_blank: true
        ) do |select|
          GisProjectLookup.all_stages.each do |stage|
            select.option(
              label: "#{stage[:code]} - #{stage[:description]}",
              value: stage[:code]
            )
          end
        end

        f.text_field(
          name: "pda_nfs_attributes[0][financial_code]",
          label: "Financial Code",
          required: false
        )
      end
    end
  end
end

