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

      end
    end
  end
end

