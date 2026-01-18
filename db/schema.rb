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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_184453) do
# Could not dump table "event_occurrences" because of following StandardError
#   Unknown type 'uuid' for column 'event_id'


# Could not dump table "events" because of following StandardError
#   Unknown type 'uuid' for column 'created_by_id'


# Could not dump table "group_memberships" because of following StandardError
#   Unknown type 'uuid' for column 'group_id'


# Could not dump table "groups" because of following StandardError
#   Unknown type 'uuid' for column 'created_by_id'


# Could not dump table "rsvps" because of following StandardError
#   Unknown type 'uuid' for column 'event_occurrence_id'


  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "event_occurrences", "events"
  add_foreign_key "events", "groups"
  add_foreign_key "events", "users", column: "created_by_id"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "rsvps", "event_occurrences"
  add_foreign_key "rsvps", "users"
end
