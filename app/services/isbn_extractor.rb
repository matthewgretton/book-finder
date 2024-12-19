require "securerandom"
require "tempfile"

module IsbnExtractor
  class << self
    def extract(photo)
      validate_photo!(photo)

      begin
        # Ensure the file is a JPEG before processing
        if photo.content_type == "image/jpeg" && !photo.tempfile.nil? && !photo.tempfile.size.zero?
          Rails.logger.info "Processing JPEG file: #{photo.tempfile.path}"
          puts "Processing JPEG file: #{photo.tempfile.path}"

          # Create a temporary file
          Tempfile.create([ "isbn_extractor", ".jpg" ]) do |tempfile|
            tempfile.binmode
            tempfile.write(photo.tempfile.read)
            tempfile.flush

            Rails.logger.info "Saved temporary file to: #{tempfile.path}"
            puts "Saved temporary file to: #{tempfile.path}"

            # Decode the barcode using the zbarimg command
            isbn = decode_barcode(tempfile.path)

            if isbn && valid_isbn?(isbn)
              return isbn
            else
              Rails.logger.info "No valid ISBN barcode found"
              return nil
            end
          end
        else
          Rails.logger.error "File is not a valid JPEG or is empty. Actual content type: #{photo.content_type}"
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

      def decode_barcode(image_path)
        output = `zbarimg --quiet --raw #{image_path}`
        if $?.success?
          output.strip
        else
          Rails.logger.error("Error decoding barcode: #{output}")
          nil
        end
      end

      def valid_isbn?(isbn)
        case isbn.length
        when 10
          valid_isbn10?(isbn)
        when 13
          valid_isbn13?(isbn)
        else
          false
        end
      end

      def valid_isbn10?(isbn)
        sum = 0
        isbn.chars.each_with_index do |char, index|
          return false unless char =~ /\d|X/
          value = (char == "X" ? 10 : char.to_i)
          sum += value * (10 - index)
        end
        sum % 11 == 0
      end

      def valid_isbn13?(isbn)
        sum = 0
        isbn.chars.each_with_index do |char, index|
          return false unless char =~ /\d/
          value = char.to_i
          sum += value * (index.even? ? 1 : 3)
        end
        sum % 10 == 0
      end
  end
end
