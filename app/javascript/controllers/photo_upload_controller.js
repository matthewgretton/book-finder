import { Controller } from "@hotwired/stimulus"
import { BrowserMultiFormatReader } from "@zxing/browser"

export default class extends Controller {
  static targets = ["fileInput", "submitButton"]
  static values = { url: String }

  async handleFileChange() {
    if (!this.fileInputTarget.files.length) return
    
    this.submitButtonTarget.value = "Scanning..."
    this.submitButtonTarget.disabled = true

    const reader = new BrowserMultiFormatReader()
    const isbns = []

    for (const file of this.fileInputTarget.files) {
      try {
        const imgUrl = URL.createObjectURL(file)
        const result = await reader.decodeFromImageUrl(imgUrl)
        if (result?.text) isbns.push(result.text)
        URL.revokeObjectURL(imgUrl)
      } catch (error) {
        console.error("Failed to scan barcode:", error)
      }
    }

    if (isbns.length) {
      window.location.href = `${this.urlValue}?isbns=${isbns.join(',')}`
    } else {
      this.submitButtonTarget.value = "Scan Barcode(s)"
      this.submitButtonTarget.disabled = false
      alert("No valid barcodes found")
    }
  }

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
}