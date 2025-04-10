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

ActiveRecord::Schema[8.0].define(version: 2025_04_06_200631) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "csv_uploads", force: :cascade do |t|
    t.string "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_csv_uploads_on_session_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "company"
    t.string "plan"
    t.boolean "newsletter"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "company_size"
    t.boolean "cfo_consultation"
  end

  create_table "quickbooks_analyses", force: :cascade do |t|
    t.integer "quickbooks_profile_id"
    t.date "start_date"
    t.date "end_date"
    t.json "detection_rules"
    t.json "results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "transactions_data"
    t.string "session_id"
    t.integer "status_progress"
    t.string "status_message"
    t.datetime "status_updated_at"
    t.boolean "status_success"
    t.boolean "completed"
    t.string "source", default: "quickbooks"
    t.index ["quickbooks_profile_id"], name: "index_quickbooks_analyses_on_quickbooks_profile_id"
    t.index ["session_id"], name: "index_quickbooks_analyses_on_session_id"
    t.index ["source"], name: "index_quickbooks_analyses_on_source"
  end

  create_table "quickbooks_profiles", force: :cascade do |t|
    t.integer "user_id"
    t.string "realm_id"
    t.json "profile_data"
    t.datetime "last_updated"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "connected_at"
    t.boolean "active", default: true
    t.string "email"
    t.string "phone"
    t.string "first_name"
    t.string "last_name"
    t.string "company_name"
    t.string "address"
    t.string "city"
    t.string "region"
    t.string "postal_code"
    t.string "country"
    t.string "last_connection_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "legal_name"
    t.json "company_info"
    t.integer "fiscal_year_start_month"
    t.index ["active"], name: "index_quickbooks_profiles_on_active"
    t.index ["company_name"], name: "index_quickbooks_profiles_on_company_name"
    t.index ["email"], name: "index_quickbooks_profiles_on_email"
    t.index ["realm_id"], name: "index_quickbooks_profiles_on_realm_id", unique: true
    t.index ["user_id"], name: "index_quickbooks_profiles_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "quickbooks_analyses", "quickbooks_profiles"
end
