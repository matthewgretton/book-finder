require "zbar"

module IsbnExtractor
  class << self
    def extract(photo)
      validate_photo!(photo)

      begin
        # Ensure the file is a JPEG before processing
        if photo.content_type == "image/jpeg" && !photo.tempfile.nil? && !photo.tempfile.size.zero?
          Rails.logger.info "Processing JPEG file: #{photo.tempfile.path}"
          puts "Processing JPEG file: #{photo.tempfile.path}"

          # Read the file content to ensure it's a valid JPEG
          file_content = File.binread(photo.tempfile.path).force_encoding("ASCII-8BIT")
          Rails.logger.info "File content starts with: #{file_content[0..10].bytes.map { |b| b.to_s(16) }.join(' ')}"

          if file_content.start_with?("\xFF\xD8".force_encoding("ASCII-8BIT"))
            begin
              image_data = photo.tempfile.read


              image = ZBar::Image.from_jpeg(image_data)
              results = image.process



              temp_file_path = "/tmp/#{SecureRandom.uuid}.jpg"
              File.open(temp_file_path, "wb") do |file|
                file.write(photo.tempfile.read)
              end

              Rails.logger.info "Saved temporary file to: #{temp_file_path}"
              puts "Saved temporary file to: #{temp_file_path}"



              Rails.logger.info "Scan results: #{results.inspect}"

              puts results
              Rails.logger.info "Scan results: #{results.inspect}"

              # Check for ISBN-13 (EAN-13 starting with 978 or 979)
              isbn = results.find { |symbol|
                symbol.type == ZBar::Symbol::EAN13 && symbol.data.start_with?("978", "979")
              }
              return isbn.data if isbn

              # Check for ISBN-10 (CODE-39 or CODE-128)
              isbn = results.find { |symbol|
                [ "CODE-39", "CODE-128" ].include?(symbol.type.to_s) && symbol.data.length == 10
              }
              return isbn.data if isbn

              Rails.logger.info "No ISBN barcode found"
              nil
            rescue StandardError => e
              Rails.logger.error "Error in ZBar processing: #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
              nil
            end
          else
            Rails.logger.error "File content is not a valid JPEG. Actual content: #{file_content[0..10].inspect}"
            nil
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
  end
end
