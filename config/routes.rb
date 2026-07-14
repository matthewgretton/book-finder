Rails.application.routes.draw do
  # Define custom routes for the search action
  get "books/search", to: "books#search", as: :search_books
  post "books/search", to: "books#search"
  get "books/isbn_lookup", to: "books#isbn_lookup", as: :isbn_lookup_books
  get "books/details", to: "books#details", as: :book_details

  # Uncomment this line for PWA support
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # We don't need the service-worker route since we're not implementing offline functionality
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check

  root "books#search"
end
