module IsbnExtractor
  ISBN_PATTERN = /(?:97[89][- ]?)?(?:\d[- ]?){9}[\dXx]/i

  def extract(photo)
    validate_photo!(photo)

    begin
      Tempfile.create([ "isbn_extract", ".jpg" ], binmode: true) do |temp_file|
        # Load image once
        image = MiniMagick::Image.read(photo.tempfile)

        # Minimal preprocessing - only what's essential for barcode reading
        image.auto_orient
        image.colorspace "Gray"

        # Try OCR on original orientation first (most common case)
        if isbn = extract_isbn_from_image(image)
          return isbn
        end

        # Only try other orientations if first attempt fails
        [ 90, 180, 270 ].each do |rotation|
          # Modify existing image instead of cloning
          image.rotate(rotation.to_s)

          if isbn = extract_isbn_from_image(image)
            return isbn
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

    def extract_isbn_from_image(image)
      ocr = RTesseract.new(image.path)
      text = ocr.to_s.strip

      isbn_match = text.match(ISBN_PATTERN)
      isbn_match[0] if isbn_match
    end

    def validate_photo!(photo)
      unless photo.is_a?(ActionDispatch::Http::UploadedFile)
        raise ArgumentError, "Invalid photo provided"
      end

      unless photo.content_type.start_with?("image/")
        raise ArgumentError, "File must be an image"
      end
    end

    module_function :extract, :extract_isbn_from_image, :validate_photo!
end
