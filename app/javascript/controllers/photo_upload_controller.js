import { Controller } from "@hotwired/stimulus"
import Quagga from "quagga"

export default class extends Controller {
  static values = { url: String }

  // This method is triggered when the "Scan Barcode(s)" button is clicked.
  startScan(event) {
    event.preventDefault()
    // Disable the button to prevent multiple clicks.
    event.currentTarget.disabled = true

    // Create (or show) a live scanner container.
    let container = document.getElementById("live-scanner-container")
    if (!container) {
      container = document.createElement("div")
      container.id = "live-scanner-container"
      // Style as needed (these dimensions match our constraints below).
      container.style.width = "640px"
      container.style.height = "480px"
      container.style.border = "1px solid #ccc"
      container.style.margin = "1rem auto"
      document.body.appendChild(container)
    }
    container.style.display = "block"

    // Initialize Quagga with a live stream.
    Quagga.init({
      inputStream: {
        name: "Live",
        type: "LiveStream",
        target: container, // Render video into our container.
        constraints: {
          width: 640,
          height: 480,
          facingMode: "environment" // Use the rear camera.
        }
      },
      decoder: {
        readers: ["ean_reader"], // ISBN-13 is encoded as EAN-13.
        tryHarder: true
      },
      locate: true
    }, (err) => {
      if (err) {
        console.error(err)
        alert("Error initializing scanner")
        event.currentTarget.disabled = false
        return
      }
      console.log("Live scanner initialized. Starting video stream...")
      Quagga.start()
    })

    // Set up the detection callback.
    Quagga.onDetected(this.onDetected.bind(this))
  }

  // Called when Quagga detects a barcode.
  onDetected(result) {
    if (result && result.codeResult && result.codeResult.code) {
      // Clean the code (remove non-digit characters).
      const isbn = result.codeResult.code.replace(/[^0-9]/g, '')
      console.log("Detected ISBN:", isbn)
      if (this.isValidISBN(isbn)) {
        // Valid ISBN found: stop scanning...
        Quagga.stop()
        // Optionally hide the live scanner container.
        const container = document.getElementById("live-scanner-container")
        if (container) {
          container.style.display = "none"
        }
        // ...and redirect to the search URL with the ISBN as a parameter.
        window.location.href = `${this.urlValue}?isbns=${isbn}`
      }
    }
  }

  // Basic validation: ISBN-13 should be 13 digits and typically start with 978 or 979.
  isValidISBN(isbn) {
    return isbn.length === 13 && (isbn.startsWith("978") || isbn.startsWith("979"))
  }
}
