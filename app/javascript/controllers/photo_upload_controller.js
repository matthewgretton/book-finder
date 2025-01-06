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

      // First attempt - standard scanning
      let isbns = await this.scanBarcodes(false)
      
      // If no results, try again with TRY_HARDER
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
        // Process image orientation before scanning
        const orientedImageUrl = await this.getOrientedImageUrl(file)
        const result = await reader.decodeFromImageUrl(orientedImageUrl)
        if (result?.text) isbns.push(result.text)
        URL.revokeObjectURL(orientedImageUrl)
      } catch (error) {
        console.error("Failed to scan barcode:", error)
      }
    }

    return isbns
  }

  async getOrientedImageUrl(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = async (e) => {
        try {
          const img = new Image()
          img.onload = () => {
            // Get orientation from EXIF data
            this.getOrientation(file).then(orientation => {
              const canvas = document.createElement('canvas')
              const ctx = canvas.getContext('2d')
              
              // Set proper canvas dimensions before transform
              if (4 < orientation && orientation < 9) {
                canvas.width = img.height
                canvas.height = img.width
              } else {
                canvas.width = img.width
                canvas.height = img.height
              }

              // Transform context based on orientation
              switch (orientation) {
                case 2: ctx.transform(-1, 0, 0, 1, img.width, 0); break
                case 3: ctx.transform(-1, 0, 0, -1, img.width, img.height); break
                case 4: ctx.transform(1, 0, 0, -1, 0, img.height); break
                case 5: ctx.transform(0, 1, 1, 0, 0, 0); break
                case 6: ctx.transform(0, 1, -1, 0, img.height, 0); break
                case 7: ctx.transform(0, -1, -1, 0, img.height, img.width); break
                case 8: ctx.transform(0, -1, 1, 0, 0, img.width); break
              }

              // Draw the image with proper orientation
              ctx.drawImage(img, 0, 0)
              
              // Convert canvas to URL
              const url = canvas.toDataURL(file.type)
              resolve(url)
            }).catch(error => {
              console.error("Error getting orientation:", error)
              // If we can't get orientation, return original image URL
              resolve(URL.createObjectURL(file))
            })
          }
          img.onerror = reject
          img.src = e.target.result
        } catch (error) {
          reject(error)
        }
      }
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  async getOrientation(file) {
    // Return 1 if the file isn't a JPEG (1 means no rotation needed)
    if (!file.type.startsWith('image/jpeg')) {
      return 1
    }

    const buffer = await file.arrayBuffer()
    const view = new DataView(buffer)
    
    if (view.getUint16(0, false) !== 0xFFD8) {
      return 1 // Not a JPEG
    }

    const length = view.byteLength
    let offset = 2

    while (offset < length) {
      const marker = view.getUint16(offset, false)
      offset += 2

      if (marker === 0xFFE1) {
        if (view.getUint32(offset += 2, false) !== 0x45786966) {
          return 1
        }
        
        const little = view.getUint16(offset += 6, false) === 0x4949
        offset += view.getUint32(offset + 4, little)

        const tags = view.getUint16(offset, little)
        offset += 2

        for (let i = 0; i < tags; i++) {
          if (view.getUint16(offset + (i * 12), little) === 0x0112) {
            return view.getUint16(offset + (i * 12) + 8, little)
          }
        }
      } else if ((marker & 0xFF00) !== 0xFF00) {
        break
      } else {
        offset += view.getUint16(offset, false)
      }
    }
    
    return 1
  }

  promptFileSelection(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
}