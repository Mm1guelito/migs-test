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

ActiveRecord::Schema[7.1].define(version: 2025_05_26_114721) do
  create_table "bot_configurations", force: :cascade do |t|
    t.string "facebook"
    t.string "linkedin"
    t.integer "time_interval"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calendar_events", force: :cascade do |t|
    t.string "title"
    t.string "unique_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "organizer"
    t.text "description"
    t.text "attendees"
    t.string "google_calendar_link"
    t.string "location"
    t.string "hangout_link"
    t.integer "bot_time"
    t.boolean "bot_join", default: true, null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "meeting_url"
    t.integer "google_account_id"
    t.string "timezone"
    t.datetime "created_date"
    t.string "date"
    t.string "start_time_24h"
    t.string "end_time_24h"
    t.string "recall_bot_id"
    t.json "recall_transcript"
    t.string "recall_video_url"
    t.index ["google_account_id"], name: "index_calendar_events_on_google_account_id"
    t.index ["unique_id", "user_id", "google_account_id"], name: "index_calendar_events_on_unique_id_and_user_and_account", unique: true
    t.index ["unique_id"], name: "index_calendar_events_on_unique_id", unique: true
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "google_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "email", null: false
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.string "first_name"
    t.string "last_name"
    t.string "google_id"
    t.boolean "is_primary", default: false
    t.boolean "calendar_sync_enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_google_accounts_on_email", unique: true
    t.index ["user_id"], name: "index_google_accounts_on_user_id"
  end

  create_table "linkedin_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "email", null: false
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.string "first_name"
    t.string "last_name"
    t.string "linkedin_id"
    t.string "profile_url"
    t.string "headline"
    t.boolean "is_primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_linkedin_accounts_on_email", unique: true
    t.index ["linkedin_id"], name: "index_linkedin_accounts_on_linkedin_id", unique: true
    t.index ["user_id"], name: "index_linkedin_accounts_on_user_id"
  end

  create_table "social_bot_configs", force: :cascade do |t|
    t.integer "facebook", default: 0
    t.integer "linkedin", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "social_posts", force: :cascade do |t|
    t.string "platform", default: "linkedin"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "type"
    t.string "description"
    t.integer "user_id"
    t.index ["user_id"], name: "index_social_posts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "google_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "facebook_id"
    t.string "facebook_email"
    t.string "facebook_token"
    t.datetime "facebook_token_expires_at"
  end

  add_foreign_key "calendar_events", "google_accounts", on_delete: :cascade
  add_foreign_key "calendar_events", "users"
  add_foreign_key "google_accounts", "users"
  add_foreign_key "linkedin_accounts", "users"
  add_foreign_key "social_posts", "users"
end
