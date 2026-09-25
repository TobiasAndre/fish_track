# Catálogo das páginas do sistema e das ações que cada uma aceita. É a fonte
# única para a tela de perfis e para a futura checagem de acesso.
#
# Ações:
#   read   -> visualizar (index/show e relatórios)
#   write  -> criar      (new/create)
#   edit   -> editar     (edit/update)
#   delete -> excluir    (destroy)
#
# `controllers` lista os controllers que pertencem à página (ex.: a página
# Funcionários também cobre reajustes e férias), para o mapeamento controller ->
# página. Páginas exclusivas do administrador do sistema (Administração) e a
# seleção de empresa ficam de fora, em EXCLUDED_CONTROLLERS.
class PermissionCatalog
  ACTIONS = %w[read write edit delete].freeze
  ACTION_LABELS = { "read" => "Visualizar", "write" => "Criar", "edit" => "Editar", "delete" => "Excluir" }.freeze

  ALL = ACTIONS
  READ_ONLY = %w[read].freeze

  Resource = Struct.new(:key, :label, :actions, :controllers, keyword_init: true) do
    def allows?(action)
      actions.include?(action.to_s)
    end
  end

  Group = Struct.new(:label, :resources, keyword_init: true)

  def self.build(key, label, actions: ALL, controllers: [key])
    Resource.new(key: key, label: label, actions: actions, controllers: controllers)
  end

  GROUPS = [
    Group.new(label: "Geral", resources: [
      build("dashboard", "Dashboard", actions: READ_ONLY, controllers: %w[dashboard dashboards])
    ]),
    Group.new(label: "Cadastros", resources: [
      build("units", "Unidades"),
      build("ponds", "Tanques"),
      build("silos", "Silos"),
      build("suppliers", "Fornecedores"),
      build("customers", "Clientes"),
      build("integrateds", "Integrados"),
      build("products", "Produtos"),
      build("payment_terms", "Condições de pagamento"),
      build("payment_methods", "Formas de pagamento"),
      build("employees", "Funcionários", controllers: %w[employees employee_salary_changes employee_vacations]),
      build("feeding_tables", "Regras de Arraçoamento", controllers: %w[feeding_tables feeding_strategy_items]),
      build("feeding_brands", "Marcas de Ração"),
      build("feeding_types", "Tipos de Ração")
    ]),
    Group.new(label: "Lançamentos", resources: [
      build("batches", "Lotes", controllers: %w[batches stocking_events]),
      build("biometry_events", "Biometria"),
      build("mortality_events", "Mortalidade"),
      build("feeding_events", "Ração (arraçoamento lançado)"),
      build("silo_stock_entries", "Estoque de Ração"),
      build("water_quality_readings", "Qualidade de Água"),
      build("loading_events", "Carregamento"),
      build("payroll", "Folha", controllers: %w[payroll payroll_items]),
      build("financial_entries", "Financeiro", controllers: %w[financial_entries financial_payments]),
      build("orders", "Pedidos"),
      build("simulations", "Orçamentos")
    ]),
    Group.new(label: "Relatórios", resources: [
      build("batch_reports", "Relatório de Lote", actions: READ_ONLY),
      build("loading_reports", "Relatório de Carregamentos", actions: READ_ONLY),
      build("batch_results", "Resultado por Lote", actions: READ_ONLY),
      # Além de visualizar, a calibração de tempo do tanque é uma edição.
      build("feeding_plans", "Arraçoamento", actions: %w[read edit])
    ])
  ].freeze

  # Controllers sem página de negócio: seleção de empresa e telas do administrador
  # do sistema (o namespace admin/ é tratado por prefixo).
  EXCLUDED_CONTROLLERS = %w[tenant_selections access_profiles].freeze
  EXCLUDED_PREFIXES = %w[admin/ users/ devise/ rails/ active_storage/ action_mailbox/ turbo/ health].freeze

  class << self
    def groups
      GROUPS
    end

    def resources
      @resources ||= GROUPS.flat_map(&:resources)
    end

    def find(key)
      resources.find { |resource| resource.key == key.to_s }
    end

    def valid?(resource_key, action)
      find(resource_key)&.allows?(action) || false
    end

    def resource_for_controller(controller_path)
      resources.find { |resource| resource.controllers.include?(controller_path.to_s) }
    end

    def covered_controllers
      resources.flat_map(&:controllers)
    end
  end
end
