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

ActiveRecord::Schema[7.1].define(version: 2025_12_25_145051) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "batch_events", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.string "event_type", null: false
    t.date "occurred_on", null: false
    t.integer "quantity"
    t.decimal "avg_weight_g", precision: 10, scale: 2
    t.decimal "feed_kg", precision: 10, scale: 3
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id", "occurred_on"], name: "index_batch_events_on_batch_id_and_occurred_on"
    t.index ["batch_id"], name: "index_batch_events_on_batch_id"
    t.index ["event_type"], name: "index_batch_events_on_event_type"
  end

  create_table "batches", force: :cascade do |t|
    t.bigint "pond_id", null: false
    t.string "name", null: false
    t.string "species"
    t.string "status", default: "active", null: false
    t.string "stage", default: "juvenile", null: false
    t.date "started_on", null: false
    t.date "closed_on"
    t.integer "initial_quantity"
    t.integer "current_quantity"
    t.decimal "avg_weight_g", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pond_id", "name"], name: "index_batches_on_pond_id_and_name"
    t.index ["pond_id"], name: "index_batches_on_pond_id"
    t.index ["started_on"], name: "index_batches_on_started_on"
    t.index ["status", "stage"], name: "index_batches_on_status_and_stage"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_employees_on_company_id_and_name"
    t.index ["company_id"], name: "index_employees_on_company_id"
  end

  create_table "financial_entries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "unit_id"
    t.bigint "batch_id"
    t.string "entry_type", null: false
    t.string "stage", default: "general", null: false
    t.date "occurred_on", null: false
    t.bigint "amount_cents", null: false
    t.string "description", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_financial_entries_on_batch_id"
    t.index ["company_id", "occurred_on"], name: "index_financial_entries_on_company_id_and_occurred_on"
    t.index ["company_id"], name: "index_financial_entries_on_company_id"
    t.index ["entry_type"], name: "index_financial_entries_on_entry_type"
    t.index ["stage"], name: "index_financial_entries_on_stage"
    t.index ["unit_id"], name: "index_financial_entries_on_unit_id"
  end

  create_table "payroll_items", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "employee_id", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.bigint "amount_cents", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "year", "month"], name: "index_payroll_items_on_company_id_and_year_and_month"
    t.index ["company_id"], name: "index_payroll_items_on_company_id"
    t.index ["employee_id", "year", "month"], name: "index_payroll_items_on_employee_id_and_year_and_month", unique: true
    t.index ["employee_id"], name: "index_payroll_items_on_employee_id"
  end

  create_table "ponds", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.string "name", null: false
    t.decimal "capacity", precision: 12, scale: 2
    t.string "capacity_unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "name"], name: "index_ponds_on_unit_id_and_name", unique: true
    t.index ["unit_id"], name: "index_ponds_on_unit_id"
  end

  create_table "units", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_units_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_units_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "name", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "batch_events", "batches"
  add_foreign_key "batches", "ponds"
  add_foreign_key "employees", "companies"
  add_foreign_key "financial_entries", "batches"
  add_foreign_key "financial_entries", "companies"
  add_foreign_key "financial_entries", "units"
  add_foreign_key "payroll_items", "companies"
  add_foreign_key "payroll_items", "employees"
  add_foreign_key "ponds", "units"
  add_foreign_key "units", "companies"
  add_foreign_key "users", "companies"
end
