# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@zxing/browser", to: "https://cdn.jsdelivr.net/npm/@zxing/browser@0.1.5/+esm"
pin "@zxing/library", to: "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm"
pin "ts-custom-error", to: "https://cdn.jsdelivr.net/npm/ts-custom-error@3.3.1/+esm"
