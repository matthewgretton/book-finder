class SimplifyBooksSchema < ActiveRecord::Migration[8.0]
  def change
    # Drop the book_editions table first since it references books
    drop_table :book_editions

    # Drop and recreate the books table with just ISBN
    drop_table :books
    create_table :books do |t|
      t.string :isbn, null: false
      t.timestamps
    end

    add_index :books, :isbn, unique: true
  end
end
