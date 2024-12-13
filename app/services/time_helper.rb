module TimeHelper
  def time_function(function_name)
    start_time = Time.now
    result = yield
    end_time = Time.now
    elapsed_time = end_time - start_time
    Rails.logger.info "#{function_name} executed in #{elapsed_time} seconds"
    result
  end

  module_function :time_function
end
