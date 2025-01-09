class CreateBookEditions < ActiveRecord::Migration[8.0]
  def up
    create_table :book_editions do |t|
      t.references :book, null: false, foreign_key: true
      t.string :isbn, null: false
      t.integer :publication_year, null: false
      t.timestamps

      t.index :isbn, unique: true
    end

    Book.find_each do |book|
      BookEdition.create!(
        book: book,
        isbn: book.isbn,
        publication_year: book.published,
        created_at: book.created_at,
        updated_at: book.updated_at
      )
    end

    remove_columns :books, :isbn, :published
  end

  def down
    add_column :books, :isbn, :string
    add_column :books, :published, :integer

    BookEdition.find_each do |edition|
      book = edition.book
      book.update!(
        isbn: edition.isbn,
        published: edition.publication_year
      )
    end

    add_index :books, :isbn, unique: true
    change_column_null :books, :isbn, false
    change_column_null :books, :published, false

    drop_table :book_editions
  end
end
