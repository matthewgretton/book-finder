module IsbnExtractor
  ISBN_PATTERN = /(?:97[89][- ]?)?(?:\d[- ]?){9}[\dXx]/i

  def extract(photo)
    validate_photo!(photo)

    begin
      Tempfile.create([ "isbn_extract", ".jpg" ], binmode: true) do |temp_file|
        image = MiniMagick::Image.read(photo.tempfile)

        # Basic preprocessing
        image.auto_orient
        image.colorspace "Gray"
        image.contrast
        image.deskew("40%")

        # Try each orientation until we find an ISBN
        [ 0, 90, 180, 270 ].each do |rotation|
          rotated_image = image.clone
          rotated_image.rotate(rotation.to_s) if rotation != 0

          ocr = RTesseract.new(rotated_image.path)
          text = ocr.to_s.strip

          Rails.logger.info "OCR attempt with rotation #{rotation}°:"
          Rails.logger.info text

          isbn_match = text.match(ISBN_PATTERN)
          if isbn_match
            Rails.logger.info "Found ISBN at rotation #{rotation}°"
            return isbn_match[0]
          end
        end

        Rails.logger.info "No ISBN found in any orientation"
        nil
      end
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

    module_function :extract, :validate_photo!
end
