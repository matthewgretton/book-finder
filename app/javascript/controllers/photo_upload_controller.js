import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput"]

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }

  handleFileChange() {
    if (this.fileInputTarget.files.length > 0) {
      this.element.requestSubmit()
    }
  }
}