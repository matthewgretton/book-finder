class BookEdition < ApplicationRecord
  belongs_to :book
  validates :isbn, presence: true, uniqueness: true
  validates :publication_year, presence: true
end
