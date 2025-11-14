module Projects
  module Settings
    class AdditionalAttributesForm < ApplicationForm
      form do |f|
        f.select_list(
          name: :status,
          label: attribute_name(:status),
          required: false,
          include_blank: true
        ) do |select|
          ProjectStatusLookup.all_statuses.each do |status_lookup|
            select.option(
              label: status_lookup.label,
              value: status_lookup.id,
              selected: model.status == status_lookup.id
            )
          end
        end

        f.text_field(
          name: :centroid,
          label: attribute_name(:centroid),
          required: false
        )

        f.text_field(
          name: :external_project_id,
          label: attribute_name(:external_project_id),
          required: false
        )
      end
    end
  end
end

