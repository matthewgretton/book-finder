# Gemfile additions:
# gem 'zbar'
# gem 'ruby-vips'  # Required by ZBar for image processing

module IsbnExtractor
  class << self
    def extract(photo)
      validate_photo!(photo)

      begin
        results = ZBar::Image.from_path(photo.tempfile.path).process

        # Check for ISBN-13 (EAN-13 starting with 978 or 979)
        # We need this check because EAN-13 is used for all retail products,
        # not just books. Only 978/979 prefix indicates it's a book ISBN.
        isbn = results.find { |result|
          result.symbology == "EAN-13" && result.data.start_with?("978", "979")
        }
        return isbn.data if isbn

        # Check for ISBN-10 (CODE-39 or CODE-128)
        isbn = results.find { |result|
          [ "CODE-39", "CODE-128" ].include?(result.symbology) && result.data.length == 10
        }
        return isbn.data if isbn

        Rails.logger.info "No ISBN barcode found"
        nil
      rescue StandardError => e
        Rails.logger.error "Error in ISBN extraction: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    private

      def validate_photo!(photo)
        unless photo.is_a?(ActionDispatch::Http::UploadedFile)
          raise ArgumentError, "Invalid photo provided"
        end

        unless photo.content_type.start_with?("image/")
          raise ArgumentError, "File must be an image"
        end
      end
  end
end
