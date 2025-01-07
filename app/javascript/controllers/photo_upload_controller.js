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
        const processedImage = await this.processImage(file)
        const imageUrl = URL.createObjectURL(processedImage)
        try {
          const result = await reader.decodeFromImageUrl(imageUrl)
          if (result?.text) {
            isbns.push(result.text)
          }
        } finally {
          URL.revokeObjectURL(imageUrl)
        }
      } catch (error) {
        // Silent fail for individual files
      }
    }

    return isbns
  }

  async processImage(file) {
    return new Promise((resolve, reject) => {
      const img = new Image()
      let objectUrl = null
      
      img.onload = () => {
        let width = img.naturalWidth
        let height = img.naturalHeight
        const maxDimension = 1000

        if (width > height && width > maxDimension) {
          height = (height * maxDimension) / width
          width = maxDimension
        } else if (height > maxDimension) {
          width = (width * maxDimension) / height
          height = maxDimension
        }

        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')
        
        canvas.width = width
        canvas.height = height

        ctx.imageSmoothingEnabled = true
        ctx.imageSmoothingQuality = 'high'

        ctx.drawImage(img, 0, 0, width, height)

        canvas.toBlob(blob => {
          if (objectUrl) {
            URL.revokeObjectURL(objectUrl)
          }
          resolve(blob)
        }, 'image/jpeg', 0.95)
      }
      
      img.onerror = (error) => {
        if (objectUrl) {
          URL.revokeObjectURL(objectUrl)
        }
        reject(error)
      }

      objectUrl = URL.createObjectURL(file)
      img.src = objectUrl
    })
  }

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
}