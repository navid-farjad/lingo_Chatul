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

ActiveRecord::Schema[8.1].define(version: 2026_05_03_100005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cards", force: :cascade do |t|
    t.string "audio_url"
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.jsonb "generation_metadata", default: {}, null: false
    t.string "image_url"
    t.text "story_text"
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.index ["word_id"], name: "index_cards_on_word_id", unique: true
  end

  create_table "languages", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "user_card_states", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.integer "correct_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "incorrect_count", default: 0, null: false
    t.datetime "last_reviewed_at"
    t.integer "leitner_box", default: 1, null: false
    t.datetime "next_review_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id"], name: "index_user_card_states_on_card_id"
    t.index ["user_id", "card_id"], name: "index_user_card_states_on_user_id_and_card_id", unique: true
    t.index ["user_id", "next_review_at"], name: "index_user_card_states_on_user_id_and_next_review_at"
    t.index ["user_id"], name: "index_user_card_states_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_token", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.string "tier", default: "anonymous", null: false
    t.datetime "updated_at", null: false
    t.index ["device_token"], name: "index_users_on_device_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
  end

  create_table "words", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "english", null: false
    t.bigint "language_id", null: false
    t.string "native", null: false
    t.text "notes"
    t.string "part_of_speech"
    t.string "romanization"
    t.datetime "updated_at", null: false
    t.index ["language_id", "native"], name: "index_words_on_language_id_and_native", unique: true
    t.index ["language_id"], name: "index_words_on_language_id"
  end

  add_foreign_key "cards", "words"
  add_foreign_key "user_card_states", "cards"
  add_foreign_key "user_card_states", "users"
  add_foreign_key "words", "languages"
end
