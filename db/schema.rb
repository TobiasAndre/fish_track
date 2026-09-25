# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_25_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_profile_permissions", force: :cascade do |t|
    t.bigint "access_profile_id", null: false
    t.string "action", null: false
    t.string "resource", null: false
    t.index ["access_profile_id", "resource", "action"], name: "index_access_profile_permissions_uniqueness", unique: true
    t.index ["access_profile_id"], name: "index_access_profile_permissions_on_access_profile_id"
  end

  create_table "access_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_access_profiles_on_lower_name", unique: true
  end

  create_table "activity_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "event_type"
    t.string "ip_address"
    t.bigint "resource_id"
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_activity_logs_on_company_id"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_activity_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "batch_stockings", force: :cascade do |t|
    t.decimal "avg_weight_g", precision: 10, scale: 2
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.decimal "current_biomass_kg", precision: 12, scale: 3
    t.integer "current_quantity"
    t.bigint "pond_id", null: false
    t.integer "quantity", null: false
    t.date "stocked_on", null: false
    t.bigint "supplier_id"
    t.datetime "updated_at", null: false
    t.index ["batch_id", "pond_id", "stocked_on"], name: "idx_batch_stockings_batch_pond_date"
    t.index ["batch_id"], name: "index_batch_stockings_on_batch_id"
    t.index ["pond_id"], name: "index_batch_stockings_on_pond_id"
    t.index ["supplier_id"], name: "index_batch_stockings_on_supplier_id"
  end

  create_table "batches", force: :cascade do |t|
    t.decimal "avg_weight_g", precision: 10, scale: 2
    t.date "closed_on"
    t.datetime "created_at", null: false
    t.decimal "current_biomass_kg", precision: 14, scale: 3
    t.integer "current_quantity"
    t.integer "initial_quantity"
    t.string "name", null: false
    t.bigint "product_id"
    t.string "species"
    t.string "stage", default: "juvenile", null: false
    t.date "started_on", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_batches_on_name"
    t.index ["product_id"], name: "index_batches_on_product_id"
    t.index ["started_on"], name: "index_batches_on_started_on"
    t.index ["status", "stage"], name: "index_batches_on_status_and_stage"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.string "print_message_line_1"
    t.string "print_message_line_2"
    t.string "tenant_name", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_name"], name: "index_companies_on_tenant_name", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.string "address_complement"
    t.string "address_number"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "neighborhood"
    t.string "phone"
    t.string "postal_code"
    t.string "state"
    t.string "state_registration"
    t.string "tax_id"
    t.datetime "updated_at", null: false
  end

  create_table "employee_salary_changes", force: :cascade do |t|
    t.string "change_type", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.date "effective_on", null: false
    t.bigint "employee_id", null: false
    t.bigint "previous_salary_cents"
    t.text "reason"
    t.bigint "salary_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["change_type"], name: "index_employee_salary_changes_on_change_type"
    t.index ["created_by_id"], name: "index_employee_salary_changes_on_created_by_id"
    t.index ["effective_on"], name: "index_employee_salary_changes_on_effective_on"
    t.index ["employee_id", "effective_on"], name: "idx_employee_salary_changes_on_employee_and_effective_on"
    t.index ["employee_id"], name: "index_employee_salary_changes_on_employee_id"
  end

  create_table "employee_vacations", force: :cascade do |t|
    t.date "accrual_ended_on", null: false
    t.date "accrual_started_on", null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.integer "entitled_days", default: 30, null: false
    t.text "notes"
    t.date "paid_on"
    t.bigint "payment_amount_cents"
    t.date "payment_due_on"
    t.date "scheduled_end_on"
    t.date "scheduled_start_on"
    t.string "status", default: "accruing", null: false
    t.integer "taken_days", default: 0, null: false
    t.date "taken_end_on"
    t.date "taken_start_on"
    t.datetime "updated_at", null: false
    t.index ["employee_id", "accrual_started_on"], name: "idx_employee_vacations_on_employee_and_accrual_start"
    t.index ["employee_id"], name: "index_employee_vacations_on_employee_id"
    t.index ["payment_due_on"], name: "index_employee_vacations_on_payment_due_on"
    t.index ["status"], name: "index_employee_vacations_on_status"
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.string "name", null: false
    t.text "notes"
    t.string "role"
    t.bigint "salary_cents", default: 0, null: false
    t.string "share_token"
    t.date "started_on", default: -> { "CURRENT_DATE" }, null: false
    t.string "status", default: "active", null: false
    t.date "terminated_on"
    t.bigint "unit_id"
    t.datetime "updated_at", null: false
    t.index ["department"], name: "index_employees_on_department"
    t.index ["name"], name: "index_employees_on_name"
    t.index ["salary_cents"], name: "index_employees_on_salary_cents"
    t.index ["share_token"], name: "index_employees_on_share_token", unique: true
    t.index ["status"], name: "index_employees_on_status"
    t.index ["unit_id"], name: "index_employees_on_unit_id"
  end

  create_table "feeding_brands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower(btrim((name)::text))", name: "index_feeding_brands_on_normalized_name", unique: true
  end

  create_table "feeding_strategy_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "feeding_percentage", precision: 5, scale: 2, null: false
    t.bigint "feeding_table_id", null: false
    t.bigint "feeding_temperature_range_id", null: false
    t.bigint "feeding_weight_range_id", null: false
    t.datetime "updated_at", null: false
    t.index ["feeding_table_id", "feeding_weight_range_id", "feeding_temperature_range_id"], name: "idx_feeding_strategy_items_unique_cell", unique: true
    t.index ["feeding_table_id"], name: "index_feeding_strategy_items_on_feeding_table_id"
    t.index ["feeding_temperature_range_id"], name: "index_feeding_strategy_items_on_feeding_temperature_range_id"
    t.index ["feeding_weight_range_id"], name: "index_feeding_strategy_items_on_feeding_weight_range_id"
  end

  create_table "feeding_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "share_token"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_feeding_tables_on_name", unique: true
    t.index ["share_token"], name: "index_feeding_tables_on_share_token", unique: true
  end

  create_table "feeding_temperature_ranges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "temperature_from", precision: 5, scale: 2, null: false
    t.decimal "temperature_to", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
  end

  create_table "feeding_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "feeding_brand_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "feeding_brand_id, lower(btrim((name)::text))", name: "index_feeding_types_on_brand_and_normalized_name", unique: true
    t.index ["feeding_brand_id"], name: "index_feeding_types_on_feeding_brand_id"
  end

  create_table "feeding_weight_ranges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_from", precision: 10, scale: 2, null: false
    t.decimal "weight_to", precision: 10, scale: 2, null: false
  end

  create_table "financial_entries", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "batch_id"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.date "due_on", null: false
    t.string "entry_type", null: false
    t.text "notes"
    t.date "occurred_on", null: false
    t.bigint "paid_cents", default: 0, null: false
    t.bigint "payroll_item_id"
    t.date "settled_on"
    t.bigint "silo_stock_entry_id"
    t.string "stage", default: "general", null: false
    t.bigint "stocking_event_id"
    t.bigint "unit_id"
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_financial_entries_on_batch_id"
    t.index ["due_on"], name: "index_financial_entries_on_due_on"
    t.index ["entry_type"], name: "index_financial_entries_on_entry_type"
    t.index ["payroll_item_id"], name: "index_financial_entries_on_payroll_item_id"
    t.index ["settled_on"], name: "index_financial_entries_on_settled_on"
    t.index ["silo_stock_entry_id"], name: "index_financial_entries_on_silo_stock_entry_id"
    t.index ["stage"], name: "index_financial_entries_on_stage"
    t.index ["stocking_event_id"], name: "index_financial_entries_on_stocking_event_id"
    t.index ["unit_id"], name: "index_financial_entries_on_unit_id"
  end

  create_table "financial_payments", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "financial_entry_id", null: false
    t.text "notes"
    t.date "paid_on", null: false
    t.datetime "updated_at", null: false
    t.index ["financial_entry_id"], name: "index_financial_payments_on_financial_entry_id"
    t.index ["paid_on"], name: "index_financial_payments_on_paid_on"
  end

  create_table "integrateds", force: :cascade do |t|
    t.string "address"
    t.string "address_complement"
    t.string "address_number"
    t.string "city"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "email"
    t.string "name", null: false
    t.string "neighborhood"
    t.text "notes"
    t.string "phone"
    t.string "postal_code"
    t.string "state"
    t.string "state_registration"
    t.string "tax_id"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "name"], name: "index_integrateds_on_customer_id_and_name"
    t.index ["customer_id"], name: "index_integrateds_on_customer_id"
    t.index ["name"], name: "index_integrateds_on_name"
    t.index ["tax_id"], name: "index_integrateds_on_tax_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_memberships_on_company_id"
    t.index ["user_id", "company_id"], name: "index_memberships_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.bigint "total_cents", default: 0, null: false
    t.string "unit", default: "kg", null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "notes"
    t.date "occurred_on", default: -> { "CURRENT_DATE" }, null: false
    t.bigint "payment_method_id", null: false
    t.bigint "payment_term_id", null: false
    t.string "status", default: "draft", null: false
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["occurred_on"], name: "index_orders_on_occurred_on"
    t.index ["payment_method_id"], name: "index_orders_on_payment_method_id"
    t.index ["payment_term_id"], name: "index_orders_on_payment_term_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_payment_methods_on_active"
    t.index ["name"], name: "index_payment_methods_on_name"
  end

  create_table "payment_terms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "day_offsets", default: [], null: false
    t.integer "days"
    t.text "description"
    t.integer "installments_count", default: 1, null: false
    t.integer "interval_days", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_payment_terms_on_active"
    t.index ["name"], name: "index_payment_terms_on_name", unique: true
  end

  create_table "payroll_items", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.integer "installment_number"
    t.integer "installments_count"
    t.string "item_type", default: "salary", null: false
    t.integer "month", null: false
    t.text "notes"
    t.date "occurred_on", default: -> { "CURRENT_DATE" }, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["employee_id"], name: "index_payroll_items_on_employee_id"
    t.index ["occurred_on"], name: "index_payroll_items_on_occurred_on"
    t.index ["year", "month"], name: "index_payroll_items_on_year_and_month"
  end

  create_table "ponds", force: :cascade do |t|
    t.integer "capacity"
    t.string "capacity_unit"
    t.datetime "created_at", null: false
    t.decimal "feed_sample_kg", precision: 10, scale: 3
    t.decimal "feed_sample_seconds", precision: 10, scale: 2
    t.string "name", null: false
    t.integer "order_number", default: 0, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "name"], name: "index_ponds_on_unit_id_and_name", unique: true
    t.index ["unit_id"], name: "index_ponds_on_unit_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "sku"
    t.string "unit", default: "kg", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["name"], name: "index_products_on_name"
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "report_shares", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "report_type", null: false
    t.string "share_token"
    t.datetime "updated_at", null: false
    t.index ["report_type"], name: "index_report_shares_on_report_type"
    t.index ["share_token"], name: "index_report_shares_on_share_token", unique: true
  end

  create_table "silo_stock_entries", force: :cascade do |t|
    t.bigint "batch_id"
    t.datetime "created_at", null: false
    t.date "due_on"
    t.bigint "feeding_brand_id", null: false
    t.bigint "feeding_type_id", null: false
    t.text "notes"
    t.date "occurred_on", null: false
    t.bigint "payment_method_id"
    t.bigint "payment_term_id"
    t.integer "price_per_kg_cents", default: 0, null: false
    t.decimal "quantity_kg", precision: 10, scale: 3, null: false
    t.bigint "silo_id"
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_silo_stock_entries_on_batch_id"
    t.index ["feeding_brand_id"], name: "index_silo_stock_entries_on_feeding_brand_id"
    t.index ["feeding_type_id"], name: "index_silo_stock_entries_on_feeding_type_id"
    t.index ["occurred_on"], name: "index_silo_stock_entries_on_occurred_on"
    t.index ["payment_method_id"], name: "index_silo_stock_entries_on_payment_method_id"
    t.index ["payment_term_id"], name: "index_silo_stock_entries_on_payment_term_id"
    t.index ["silo_id"], name: "index_silo_stock_entries_on_silo_id"
  end

  create_table "silos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index "unit_id, lower(btrim((name)::text))", name: "index_silos_on_unit_and_normalized_name", unique: true
    t.index ["unit_id"], name: "index_silos_on_unit_id"
  end

  create_table "simulation_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "simulation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_simulation_products_on_product_id"
    t.index ["simulation_id", "product_id"], name: "index_simulation_products_on_simulation_id_and_product_id", unique: true
    t.index ["simulation_id"], name: "index_simulation_products_on_simulation_id"
  end

  create_table "simulations", force: :cascade do |t|
    t.decimal "avg_weight_kg", precision: 10, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "freight_cost_cents", default: 0, null: false
    t.bigint "integrated_id"
    t.bigint "loading_cost_cents", default: 0, null: false
    t.integer "loading_count", default: 1, null: false
    t.text "notes"
    t.bigint "price_per_kg_cents", default: 0, null: false
    t.integer "quantity", default: 0, null: false
    t.string "share_token"
    t.date "simulated_on", null: false
    t.bigint "thousand_value_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.decimal "total_weight_kg", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_simulations_on_customer_id"
    t.index ["integrated_id"], name: "index_simulations_on_integrated_id"
    t.index ["share_token"], name: "index_simulations_on_share_token", unique: true
    t.index ["simulated_on"], name: "index_simulations_on_simulated_on"
  end

  create_table "stocking_events", force: :cascade do |t|
    t.decimal "avg_weight_g", precision: 10, scale: 2
    t.bigint "batch_stocking_id", null: false
    t.decimal "biomass", precision: 12, scale: 3
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "event_type", null: false
    t.decimal "feed_conversion", precision: 14, scale: 3
    t.decimal "feed_kg", precision: 10, scale: 3
    t.bigint "feeding_brand_id"
    t.bigint "feeding_type_id"
    t.integer "freight_cost_cents"
    t.decimal "gpd", precision: 10, scale: 3
    t.string "gta_number"
    t.bigint "integrated_id"
    t.string "invoice_number"
    t.integer "loading_cost_cents"
    t.string "loading_destination"
    t.text "notes"
    t.date "occurred_on", null: false
    t.date "payment_date"
    t.string "payment_method"
    t.bigint "payment_method_id"
    t.bigint "payment_term_id"
    t.integer "price_per_kg_cents"
    t.integer "quantity"
    t.string "share_token"
    t.bigint "supplier_id"
    t.decimal "tax_percentage", precision: 5, scale: 2
    t.integer "thousand_value_cents"
    t.bigint "total_cents", default: 0, null: false
    t.decimal "total_weight_kg", precision: 10, scale: 3
    t.datetime "updated_at", null: false
    t.integer "volume"
    t.decimal "weight_gain_kg", precision: 12, scale: 3
    t.index ["batch_stocking_id", "occurred_on"], name: "idx_stocking_events_on_stocking_and_date"
    t.index ["batch_stocking_id"], name: "index_stocking_events_on_batch_stocking_id"
    t.index ["customer_id"], name: "index_stocking_events_on_customer_id"
    t.index ["event_type"], name: "index_stocking_events_on_event_type"
    t.index ["feeding_brand_id"], name: "index_stocking_events_on_feeding_brand_id"
    t.index ["feeding_type_id"], name: "index_stocking_events_on_feeding_type_id"
    t.index ["integrated_id"], name: "index_stocking_events_on_integrated_id"
    t.index ["occurred_on"], name: "index_stocking_events_on_occurred_on"
    t.index ["payment_method_id"], name: "index_stocking_events_on_payment_method_id"
    t.index ["payment_term_id"], name: "index_stocking_events_on_payment_term_id"
    t.index ["share_token"], name: "index_stocking_events_on_share_token", unique: true
    t.index ["supplier_id"], name: "index_stocking_events_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "address"
    t.string "address_complement"
    t.string "address_number"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "neighborhood"
    t.string "postal_code"
    t.string "state"
    t.string "state_registration"
    t.string "tax_id"
    t.datetime "updated_at", null: false
  end

  create_table "units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_units_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.boolean "system_admin", default: false, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "water_quality_readings", force: :cascade do |t|
    t.decimal "alkalinity", precision: 8, scale: 2
    t.decimal "ammonia", precision: 7, scale: 3
    t.datetime "created_at", null: false
    t.datetime "measured_at", null: false
    t.decimal "nitrite", precision: 7, scale: 3
    t.text "notes"
    t.decimal "ph", precision: 4, scale: 2
    t.bigint "pond_id", null: false
    t.decimal "salinity", precision: 6, scale: 2
    t.datetime "updated_at", null: false
    t.index ["pond_id", "measured_at"], name: "index_water_quality_readings_on_pond_id_and_measured_at"
    t.index ["pond_id"], name: "index_water_quality_readings_on_pond_id"
  end

  add_foreign_key "access_profile_permissions", "access_profiles", on_delete: :cascade
  add_foreign_key "activity_logs", "companies"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "batch_stockings", "batches"
  add_foreign_key "batch_stockings", "ponds"
  add_foreign_key "batch_stockings", "suppliers"
  add_foreign_key "batches", "products"
  add_foreign_key "employee_salary_changes", "employees"
  add_foreign_key "employee_vacations", "employees"
  add_foreign_key "employees", "units"
  add_foreign_key "feeding_strategy_items", "feeding_tables"
  add_foreign_key "feeding_strategy_items", "feeding_temperature_ranges"
  add_foreign_key "feeding_strategy_items", "feeding_weight_ranges"
  add_foreign_key "feeding_types", "feeding_brands"
  add_foreign_key "financial_entries", "batches"
  add_foreign_key "financial_entries", "payroll_items"
  add_foreign_key "financial_entries", "silo_stock_entries"
  add_foreign_key "financial_entries", "stocking_events"
  add_foreign_key "financial_entries", "units"
  add_foreign_key "financial_payments", "financial_entries", on_delete: :cascade
  add_foreign_key "integrateds", "customers"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "payment_methods"
  add_foreign_key "orders", "payment_terms"
  add_foreign_key "payroll_items", "employees"
  add_foreign_key "ponds", "units"
  add_foreign_key "silo_stock_entries", "batches"
  add_foreign_key "silo_stock_entries", "feeding_brands"
  add_foreign_key "silo_stock_entries", "feeding_types"
  add_foreign_key "silo_stock_entries", "payment_methods"
  add_foreign_key "silo_stock_entries", "payment_terms"
  add_foreign_key "silo_stock_entries", "silos"
  add_foreign_key "silos", "units"
  add_foreign_key "simulation_products", "products"
  add_foreign_key "simulation_products", "simulations"
  add_foreign_key "simulations", "customers"
  add_foreign_key "simulations", "integrateds"
  add_foreign_key "stocking_events", "batch_stockings"
  add_foreign_key "stocking_events", "customers"
  add_foreign_key "stocking_events", "feeding_brands"
  add_foreign_key "stocking_events", "feeding_types"
  add_foreign_key "stocking_events", "integrateds"
  add_foreign_key "stocking_events", "payment_methods"
  add_foreign_key "stocking_events", "payment_terms"
  add_foreign_key "stocking_events", "suppliers"
  add_foreign_key "water_quality_readings", "ponds"
end
