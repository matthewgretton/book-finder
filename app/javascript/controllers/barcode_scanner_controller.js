import { Controller } from "@hotwired/stimulus"
import Quagga from "quagga"

export default class extends Controller {
  static values = { url: String }

  disconnect() {
    this.stopScan();
  }

  toggleScan(event) {
    event.preventDefault();
  
    // Clear out the search text input field (if it exists)
    const searchInput = document.querySelector('input[name="query"]');
    if (searchInput) {
      searchInput.value = '';
    }
  
    // Remove the books table container from the DOM
    const tableWrapper = document.querySelector('[data-table-target="wrapper"]');
    if (tableWrapper) {
      tableWrapper.remove();
    }
  
    const scanButton = document.getElementById("scan-button");
    if (scanButton.dataset.scanning === "true") {
      this.stopScan();
    } else {
      this.startScan();
    }
  }
  

  startScan() {
    const scanButton = document.getElementById("scan-button");
    const container = document.getElementById("live-scanner-container");
    if (!container) {
      console.error("No live scanner container found!");
      return;
    }

    const viewportHeight = window.visualViewport ? window.visualViewport.height : window.innerHeight;
    const safeHeight = Math.min(viewportHeight - 180, 480);
    
    container.style.height = `${safeHeight}px`;
    container.style.display = "block";

    // Mark that scanning is active and reset the button state without re-triggering the event
    scanButton.dataset.scanning = "true";
    scanButton.blur();
    scanButton.value = "Cancel";

    Quagga.init({
      inputStream: {
        name: "Live",
        type: "LiveStream",
        target: container,
        constraints: {
          width: 640,
          height: safeHeight,
          facingMode: "environment"
        }
      },
      decoder: {
        readers: ["ean_reader"],
        tryHarder: true
      },
      locate: true
    }, (err) => {
      if (err) {
        console.error(err);
        this.stopScan();
        alert("Error initializing scanner");
        return;
      }
      console.log("Live scanner initialized. Starting video stream...");
      Quagga.start();

      setTimeout(() => {
        const video = container.querySelector("video");
        if (video) {
          video.style.width = "100%";
          video.style.height = "100%";
          video.style.objectFit = "cover";
          video.style.position = "absolute";
          video.style.top = "0";
          video.style.left = "0";
        }
      }, 500);
    });

    Quagga.onDetected(this.onDetected.bind(this));
  }

  stopScan() {
    Quagga.stop();
    const scanButton = document.getElementById("scan-button");
    const container = document.getElementById("live-scanner-container");
    
    if (container) {
      container.style.display = "none";
    }
    
    if (scanButton) {
      scanButton.dataset.scanning = "false";
      scanButton.blur();
      scanButton.value = "Scan Barcode(s)";
    }
  }

  onDetected(result) {
    if (result && result.codeResult && result.codeResult.code) {
      const isbn = result.codeResult.code.replace(/[^0-9]/g, '');
      console.log("Detected ISBN:", isbn);
      if (this.isValidISBN(isbn)) {
        this.stopScan();
        window.location.href = `${this.urlValue}?isbns=${isbn}`;
      }
    }
  }

  isValidISBN(isbn) {
    return isbn.length === 13 && (isbn.startsWith("978") || isbn.startsWith("979"));
  }
}
