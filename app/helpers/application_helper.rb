module ApplicationHelper
  def enum_t(model, enum_name)
    I18n.t(
      "enums.#{model.model_name.i18n_key}.#{enum_name}.#{model.public_send(enum_name)}"
    )
  end
end
