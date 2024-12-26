require "shellwords"

module IsbnExtractor
  class << self
    def extract(photo)
      validate_photo!(photo)
      return nil if photo.tempfile.nil? || photo.tempfile.size.zero?

      Rails.logger.info "Processing file: #{photo.tempfile.path}, size=#{photo.tempfile.size}"

      # 1. Write the incoming photo to a temp file
      original_tmp = Tempfile.new([ "isbn_extractor", ".jpg" ])
      original_tmp.binmode
      original_tmp.write(photo.tempfile.read)
      original_tmp.close

      # 2. Auto-orient -> oriented.jpg
      oriented_path = "#{original_tmp.path}_oriented.jpg"
      auto_orient_cmd = [
        "convert",
        Shellwords.escape(original_tmp.path),
        "-auto-orient",
        Shellwords.escape(oriented_path)
      ].join(" ")
      execute_command(auto_orient_cmd, "Auto-orient")

      unless File.exist?(oriented_path)
        Rails.logger.error "Auto-orient failed. No file at: #{oriented_path}"
        cleanup_files(original_tmp.path, oriented_path)
        return nil
      end

      # 3. Contrast step -> oriented_contrast.jpg
      contrast_path = "#{oriented_path}_contrast.jpg"
      contrast_cmd = [
        "convert",
        Shellwords.escape(oriented_path),
        "-contrast",
        "-contrast",
        "-contrast",
        Shellwords.escape(contrast_path)
      ].join(" ")
      execute_command(contrast_cmd, "Contrast")

      unless File.exist?(contrast_path)
        Rails.logger.error "Contrast step failed. No file at: #{contrast_path}"
        cleanup_files(original_tmp.path, oriented_path, contrast_path)
        return nil
      end

      # 4. zbarimg on the contrasted image
      zbar_cmd = [
        "zbarimg",
        "-Sisbn13.enable",
        "-Sisbn10.enable",
        "--raw",
        Shellwords.escape(contrast_path)
      ].join(" ")
      output = execute_command(zbar_cmd, "ZBar", capture_output: true)
      Rails.logger.info "zbarimg output: #{output.inspect}"

      isbn = output.match(/(\d{13}|\d{9}[\dX])/)[1] rescue nil
      isbn = isbn if isbn && valid_isbn?(isbn)

      # 5. Clean up
      cleanup_files(original_tmp.path, oriented_path, contrast_path)

      isbn
    rescue StandardError => e
      Rails.logger.error "Error in ISBN extraction: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    private

      def execute_command(command, step_name, capture_output: false)
        Rails.logger.info "#{step_name} command: #{command}"
        output = capture_output ? `#{command}` : system(command)
        exit_status = $?.exitstatus
        if exit_status != 0
          Rails.logger.error "#{step_name} failed with exit status: #{exit_status}"
          Rails.logger.error "Command output: #{output}" if capture_output
        else
          Rails.logger.info "#{step_name} succeeded."
        end
        output
      end

      def validate_photo!(photo)
        raise ArgumentError, "Invalid photo provided" unless photo.is_a?(ActionDispatch::Http::UploadedFile)
        raise ArgumentError, "File must be an image" unless photo.content_type.start_with?("image/")
      end

      def cleanup_files(*paths)
        paths.each do |path|
          next unless path && File.exist?(path)
          File.delete(path)
        end
      end

      def valid_isbn?(isbn)
        case isbn.length
        when 10 then valid_isbn10?(isbn)
        when 13 then valid_isbn13?(isbn)
        else false
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
