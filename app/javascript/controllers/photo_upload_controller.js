import { Controller } from "@hotwired/stimulus"
import { BrowserMultiFormatReader } from "@zxing/browser"
import { DecodeHintType, BarcodeFormat } from "@zxing/library"

export default class extends Controller {
  static targets = ["fileInput", "submitButton"]
  static values = { url: String }

  async handleFileChange() {
    if (!this.fileInputTarget.files.length) return
    
    this.submitButtonTarget.value = "Scanning..."
    this.submitButtonTarget.disabled = true

    const hints = new Map();

    hints.set(DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.EAN_13, BarcodeFormat.ISBN, BarcodeFormat.EAN_10]);

    hints.set(DecodeHintType.TRY_HARDER, true);
    
    const reader = new BrowserMultiFormatReader(hints)
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