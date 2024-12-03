// app/javascript/controllers/file_upload_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput"]

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }

  submitForm() {
    this.element.requestSubmit()
  }
}