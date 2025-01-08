import { Controller } from "@hotwired/stimulus"
import Quagga from 'quagga'

export default class extends Controller {
  static targets = ["fileInput", "submitButton"]
  static values = { url: String }

  async handleFileChange() {
    if (!this.fileInputTarget.files.length) return
    
    try {
      this.submitButtonTarget.value = "Scanning..."
      this.submitButtonTarget.disabled = true

      const isbns = new Set()
      
      for (const file of this.fileInputTarget.files) {
        try {
          const result = await this.scanBarcode(file)
          if (result) {
            const isbn = result.replace(/[^0-9]/g, '')
            if (this.isValidISBN(isbn)) {
              console.log(`Successfully decoded ${file.name}:`, { text: isbn })
              isbns.add(isbn)
            }
          }
        } catch (error) {
          console.log(`Failed to process ${file.name}:`, error.message)
        }
      }

      const isbnArray = Array.from(isbns)
      if (isbnArray.length) {
        window.location.href = `${this.urlValue}?isbns=${isbnArray.join(',')}`
      } else {
        this.resetButton()
        alert("No barcodes found - please try again with a clearer photo")
      }
      
    } catch (error) {
      console.error('Error:', error)
      this.resetButton()
      alert("An error occurred - please try again")
    }
  }

  resetButton() {
    this.submitButtonTarget.value = "Scan Barcode(s)"
    this.submitButtonTarget.disabled = false
  }

  scanBarcode(file) {
    return new Promise((resolve, reject) => {
      const imageUrl = URL.createObjectURL(file)
      
      Quagga.decodeSingle({
        decoder: {
          readers: ["ean_reader", "ean_8_reader"],
          tryHarder: true
        },
        locate: true,
        src: imageUrl
      }, (result) => {
        URL.revokeObjectURL(imageUrl)
        
        if (result && result.codeResult) {
          resolve(result.codeResult.code)
        } else {
          resolve(null)
        }
      })
    })
  }

  isValidISBN(isbn) {
    return isbn.length === 13 && (isbn.startsWith('978') || isbn.startsWith('979'))
  }

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
}