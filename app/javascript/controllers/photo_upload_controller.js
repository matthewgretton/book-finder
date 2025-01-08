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
          // Try multiple patch sizes until one yields a result
          const result = await this.scanBarcode(file)
          if (result) {
            // Clean up the result to extract the ISBN digits
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

  // 1. The main function that tries multiple patch sizes in sequence
  async scanBarcode(file) {
    const patchSizes = ["medium", "large","small"]
    const imageUrl = URL.createObjectURL(file)

    try {
      for (const patchSize of patchSizes) {
        const code = await this.decodeWithPatchSize(imageUrl, patchSize)
        if (code) {
          return code  // Return immediately if successful
        }
      }
      return null
    } finally {
      // Always revoke the Object URL
      URL.revokeObjectURL(imageUrl)
    }
  }

  // 2. A helper function that attempts to decode with a single patchSize
  decodeWithPatchSize(imageUrl, patchSize) {
    console.log('Decoding with patch size', patchSize)

    return new Promise((resolve, reject) => {
      Quagga.decodeSingle({
        src: imageUrl,
        locate: true,
        numOfWorkers: 0,
        locator: {
          patchSize: patchSize
        },
        decoder: {
          readers: ["ean_reader"],
          tryHarder: true
        }
      }, (result) => {
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
