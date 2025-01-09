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

ActiveRecord::Schema[8.0].define(version: 2025_01_09_170246) do
  create_table "book_editions", force: :cascade do |t|
    t.integer "book_id", null: false
    t.string "isbn", null: false
    t.integer "publication_year", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_book_editions_on_book_id"
    t.index ["isbn"], name: "index_book_editions_on_isbn", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author", null: false
    t.decimal "atos_book_level", precision: 2, scale: 1
    t.decimal "ar_points", precision: 3, scale: 1
    t.string "interest_level"
    t.integer "word_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "series"
  end

  add_foreign_key "book_editions", "books"
end
