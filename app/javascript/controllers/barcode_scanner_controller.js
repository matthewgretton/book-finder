// app/javascript/controllers/barcode_scanner_controller.js
import { Controller } from "@hotwired/stimulus";
import Quagga from "quagga";

export default class extends Controller {
  static values = { url: String };

  connect() {
    // Use a Set to store unique ISBNs
    this.capturedIsbns = new Set();
    // Flag to throttle detections (prevents duplicate notifications)
    this.detectionPaused = false;
    // Store the video track for zoom control
    this.videoTrack = null;
  }

  disconnect() {
    this.stopScan();
  }

  toggleScan(event) {
    event.preventDefault();

    // Clear out the search text input field (if it exists)
    const searchInput = document.querySelector('input[name="query"]');
    if (searchInput) {
      searchInput.value = "";
    }

    // Remove the books table container from the DOM (if present)
    const tableWrapper = document.querySelector('[data-table-target="wrapper"]');
    if (tableWrapper) {
      tableWrapper.remove();
    }

    const scanButton = document.getElementById("scan-button");
    if (scanButton.dataset.scanning === "true") {
      // User pressed the button to stop scanning and look up details.
      scanButton.value = "Looking up book details...";
      this.stopScanWithoutResettingButton();
      console.log("Captured ISBNs:", Array.from(this.capturedIsbns));

      if (this.capturedIsbns.size > 0) {
        const isbnArray = Array.from(this.capturedIsbns);
        window.location.href = `${this.urlValue}?isbns=${isbnArray.join(',')}`;
      } else {
        scanButton.value = "Scan Barcode(s)";
        alert("No valid barcodes were captured. Please try scanning again.");
      }
    } else {
      // Start a new scanning session.
      this.capturedIsbns.clear();
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

    const barcodeHeight = 280;

    container.style.height = `${barcodeHeight}px`;
    container.style.display = "block";

    // Mark scanning as active.
    scanButton.dataset.scanning = "true";
    scanButton.blur();
    // Button label when scanning is active.
    scanButton.value = "Look Up Book Details";

    Quagga.init(
      {
        inputStream: {
          name: "Live",
          type: "LiveStream",
          target: container,
          constraints: {
            width: { min: 640, ideal: 1280 },
            height: { min: 480, ideal: 720 },
            facingMode: "environment",
            // Request advanced capabilities including zoom
            advanced: [
              { zoom: 2.0 },
              { focusMode: "continuous" }
            ]
          },
          // Focus on the center area of the camera for better barcode detection
          area: {
            top: "20%",
            right: "10%",
            left: "10%",
            bottom: "20%"
          }
        },
        decoder: {
          readers: ["ean_reader"],
          tryHarder: true
        },
        locator: {
          patchSize: "medium",
          halfSample: false
        },
        locate: true
      },
      (err) => {
        if (err) {
          console.error(err);
          this.stopScan();
          alert("Error initializing scanner");
          return;
        }
        console.log("Live scanner initialized. Starting video stream...");
        Quagga.start();

        // Try to apply zoom after the video stream starts
        setTimeout(() => {
          this.applyZoom(container);
          this.styleVideoElement(container);
          this.addTargetGuide(container);
        }, 500);
      }
    );

    Quagga.onDetected(this.onDetected.bind(this));
  }

  applyZoom(container) {
    const video = container.querySelector("video");
    if (!video || !video.srcObject) return;

    const tracks = video.srcObject.getVideoTracks();
    if (tracks.length === 0) return;

    this.videoTrack = tracks[0];
    const capabilities = this.videoTrack.getCapabilities?.();
    
    if (capabilities && capabilities.zoom) {
      const maxZoom = capabilities.zoom.max;
      const minZoom = capabilities.zoom.min;
      // Apply 2x zoom, or max available if less than 2x
      const targetZoom = Math.min(2.0, maxZoom);
      
      console.log(`Camera zoom capabilities: min=${minZoom}, max=${maxZoom}, applying=${targetZoom}`);
      
      this.videoTrack.applyConstraints({
        advanced: [{ zoom: targetZoom }]
      }).then(() => {
        console.log("Zoom applied successfully");
      }).catch(err => {
        console.log("Could not apply zoom:", err);
      });
    } else {
      console.log("Camera does not support zoom");
    }

    // Also try to enable continuous autofocus
    if (capabilities && capabilities.focusMode && capabilities.focusMode.includes("continuous")) {
      this.videoTrack.applyConstraints({
        advanced: [{ focusMode: "continuous" }]
      }).catch(err => {
        console.log("Could not enable continuous focus:", err);
      });
    }
  }

  styleVideoElement(container) {
    const video = container.querySelector("video");
    if (video) {
      video.style.width = "100%";
      video.style.height = "100%";
      video.style.objectFit = "cover";
      video.style.position = "absolute";
      video.style.top = "0";
      video.style.left = "0";
    }
  }

  addTargetGuide(container) {
    // Remove existing guide if any
    const existingGuide = container.querySelector(".scan-target-guide");
    if (existingGuide) existingGuide.remove();

    // Create a visual target guide to help users position the barcode
    const guide = document.createElement("div");
    guide.className = "scan-target-guide";
    guide.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 80%;
      height: 60px;
      border: 3px solid rgba(255, 255, 255, 0.8);
      border-radius: 8px;
      box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.3);
      pointer-events: none;
      z-index: 10;
    `;

    // Add helper text
    const helperText = document.createElement("div");
    helperText.style.cssText = `
      position: absolute;
      bottom: -30px;
      left: 50%;
      transform: translateX(-50%);
      color: white;
      font-size: 14px;
      text-shadow: 0 1px 3px rgba(0,0,0,0.8);
      white-space: nowrap;
    `;
    helperText.textContent = "Position barcode within the box";
    guide.appendChild(helperText);

    container.appendChild(guide);
  }

  // Stops scanning and resets the UI (including resetting the button text).
  stopScan() {
    Quagga.stop();
    this.videoTrack = null;
    const scanButton = document.getElementById("scan-button");
    const container = document.getElementById("live-scanner-container");

    if (container) {
      container.style.display = "none";
      // Remove the target guide
      const guide = container.querySelector(".scan-target-guide");
      if (guide) guide.remove();
    }

    if (scanButton) {
      scanButton.dataset.scanning = "false";
      scanButton.blur();
      scanButton.value = "Scan Barcode(s)";
    }
  }

  // Stops scanning without changing the button text (used during lookup).
  stopScanWithoutResettingButton() {
    Quagga.stop();
    this.videoTrack = null;
    const container = document.getElementById("live-scanner-container");
    if (container) {
      container.style.display = "none";
      const guide = container.querySelector(".scan-target-guide");
      if (guide) guide.remove();
    }
    const scanButton = document.getElementById("scan-button");
    if (scanButton) {
      scanButton.dataset.scanning = "false";
      scanButton.blur();
    }
  }

  onDetected(result) {
    if (this.detectionPaused) return;

    if (result && result.codeResult && result.codeResult.code) {
      // Remove any non-digit characters.
      const isbn = result.codeResult.code.replace(/[^0-9]/g, '');
      console.log("Detected ISBN:", isbn);
      if (this.isValidISBN(isbn)) {
        if (!this.capturedIsbns.has(isbn)) {
          // Add ISBN to the set
          this.capturedIsbns.add(isbn);
          // Notify the user
          this.showNotification(`Scanned ISBN: ${isbn}`);
          
          // Pause further detections temporarily to avoid duplicates
          this.detectionPaused = true;
          setTimeout(() => {
            this.detectionPaused = false;
          }, 1000);
        }
      }
    }
  }

  isValidISBN(isbn) {
    if (isbn.length !== 13 || !/^[0-9]+$/.test(isbn)) return false;
    if (!(isbn.startsWith("978") || isbn.startsWith("979"))) return false;

    // ISBN-13 checksum validation
    let sum = 0;
    for (let i = 0; i < 12; i += 1) {
      const digit = parseInt(isbn[i], 10);
      sum += i % 2 === 0 ? digit : digit * 3;
    }
    const checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit === parseInt(isbn[12], 10);
  }

  showNotification(message) {
    const container = document.getElementById("live-scanner-container");
    if (!container) return;
  
    const notification = document.createElement("div");
    notification.textContent = message;
    notification.classList.add("alert", "alert-info");
    
    // Center the notification over the video
    notification.style.position = "absolute";
    notification.style.top = "50%";
    notification.style.left = "50%";
    notification.style.transform = "translate(-50%, -50%)";
    notification.style.zIndex = "1000";
    
    // Transition settings
    notification.style.transition = "opacity 1s ease-out";
    notification.style.opacity = 1;
    
    // Adjust width settings so the box is wider and text doesn't wrap too much.
    notification.style.width = "80%";
    notification.style.maxWidth = "800px";
    notification.style.whiteSpace = "normal";
    notification.style.textAlign = "center";
    
    // Additional styling for improved visibility.
    notification.style.backgroundColor = "rgba(0, 0, 0, 0.7)";
    notification.style.color = "#fff";
    notification.style.fontSize = "1.5rem";
    notification.style.padding = "10px 20px";
    notification.style.borderRadius = "5px";
  
    container.appendChild(notification);
  
    // Fade out and remove the notification.
    setTimeout(() => {
      notification.style.opacity = 0;
      setTimeout(() => {
        notification.remove();
      }, 750);
    }, 1500);
  }
}
