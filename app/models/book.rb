class Book < ApplicationRecord
  validates :isbn, presence: true, uniqueness: true
end
