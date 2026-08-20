module ApplicationHelper
  def enum_t(model, enum_name, value: nil)
    value ||= model.public_send(enum_name)

    I18n.t(
      "enums.#{model.model_name.i18n_key}.#{enum_name}.#{value}"
    )
  end

  # Renders a column header as a link that toggles sorting by `column`,
  # preserving the current query params (filters, etc). Shows an up/down
  # arrow when this column is the active sort, or a neutral icon otherwise.
  def sortable_column_header(label, column, current_sort:, current_direction:)
    is_active = current_sort == column
    next_direction = is_active && current_direction == "asc" ? "desc" : "asc"

    icon = if is_active
      current_direction == "asc" ? "▲" : "▼"
    else
      "⇅"
    end

    icon_classes = is_active ? "text-gray-600 dark:text-gray-300" : "text-gray-300 dark:text-gray-600"

    query_params = params.except(:controller, :action, :sort, :direction).permit!

    link_to url_for(query_params.merge(sort: column, direction: next_direction)),
      class: "inline-flex items-center gap-1 hover:text-gray-900 dark:hover:text-gray-100 transition" do
      safe_join([label, content_tag(:span, icon, class: "text-[10px] #{icon_classes}")])
    end
  end
end
