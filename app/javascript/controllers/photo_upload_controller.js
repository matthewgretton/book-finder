import { Controller } from "@hotwired/stimulus"
import { BrowserMultiFormatReader } from "@zxing/browser"
import { DecodeHintType, BarcodeFormat } from "@zxing/library"

export default class extends Controller {
  static targets = ["fileInput", "submitButton"]
  static values = { url: String }

  async handleFileChange() {
    if (!this.fileInputTarget.files.length) return
    
    try {
      this.submitButtonTarget.value = "Scanning..."
      this.submitButtonTarget.disabled = true

      let isbns = await this.scanBarcodes(false)
      
      if (!isbns.length) {
        this.submitButtonTarget.value = "Trying enhanced scan..."
        await new Promise(resolve => setTimeout(resolve, 100))
        isbns = await this.scanBarcodes(true)
      }

      if (isbns.length) {
        window.location.href = `${this.urlValue}?isbns=${isbns.join(',')}`
      } else {
        this.submitButtonTarget.value = "Scan Barcode(s)"
        this.submitButtonTarget.disabled = false
        alert("No valid barcodes found - please try again with a clearer photo")
      }
    } catch (error) {
      console.error("Error in handleFileChange:", error)
      this.submitButtonTarget.value = "Scan Barcode(s)"
      this.submitButtonTarget.disabled = false
      alert("An error occurred while scanning - please try again")
    }
  }

  async scanBarcodes(tryHarder) {
    const hints = new Map()
    hints.set(DecodeHintType.POSSIBLE_FORMATS, [
      BarcodeFormat.EAN_13,
      BarcodeFormat.ISBN,
      BarcodeFormat.EAN_10
    ])

    if (tryHarder) {
      hints.set(DecodeHintType.TRY_HARDER, true)
    }
    
    const reader = new BrowserMultiFormatReader(hints)
    const isbns = []

    for (const file of this.fileInputTarget.files) {
      try {
        const orientedImage = await this.fixImageOrientation(file)
        const result = await reader.decodeFromImageUrl(URL.createObjectURL(orientedImage))
        if (result?.text) isbns.push(result.text)
      } catch (error) {
        console.error("Failed to scan barcode:", error)
      }
    }

    return isbns
  }

  async fixImageOrientation(file) {
    return new Promise((resolve, reject) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        canvas.width = img.width
        canvas.height = img.height
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0)
        canvas.toBlob(blob => resolve(blob), file.type)
      }
      img.onerror = reject
      img.src = URL.createObjectURL(file)
    })
  }

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
}