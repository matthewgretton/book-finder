class BookDetails
  include ActiveModel::Model

  attr_accessor :title, :author, :series, :atos_book_level,
                :ar_points, :interest_level, :word_count

  validates :title, presence: true
  validates :author, presence: true
  validates :series, presence: true

  # AR details group validations
  validates :atos_book_level, :ar_points, :interest_level, :word_count,
    presence: true,
    if: :ar_details_present?

  validates :atos_book_level,
    numericality: {
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 9.9
    },
    if: :atos_book_level

  validates :ar_points,
    numericality: { greater_than_or_equal_to: 0 },
    if: :ar_points

  validates :word_count,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    if: :word_count


  private

    def ar_details_present?
      atos_book_level.present? ||
      ar_points.present? ||
      interest_level.present? ||
      word_count.present?
    end
end
