class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Keep the site out of search engines entirely
  before_action :set_noindex_header

  private

    def set_noindex_header
      response.set_header("X-Robots-Tag", "noindex, nofollow")
    end
end
