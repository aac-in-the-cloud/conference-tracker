# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20240514144034) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conference_sessions", force: :cascade do |t|
    t.text     "data"
    t.string   "code"
    t.string   "conference_code"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["code"], name: "index_conference_sessions_on_code", unique: true, using: :btree
  end

  create_table "conferences", force: :cascade do |t|
    t.string   "name"
    t.text     "data"
    t.string   "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_conferences_on_code", unique: true, using: :btree
  end

  create_table "feed_weeks", force: :cascade do |t|
    t.integer "week"
    t.integer "year"
    t.string  "category"
    t.string  "sessions"
    t.index ["week", "year"], name: "index_feed_weeks_on_week_and_year", using: :btree
  end

  create_table "survey_results", force: :cascade do |t|
    t.text     "data"
    t.string   "email_hash"
    t.string   "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "email_hash"], name: "index_survey_results_on_code_and_email_hash", unique: true, using: :btree
  end

end
