// app/javascript/controllers/barcode_scanner_controller.js
import { Controller } from "@hotwired/stimulus";
import Quagga from "quagga";

export default class extends Controller {
  static values = { url: String };

  connect() {
    // Use a Set to store unique ISBNs.
    this.capturedISBNs = new Set();
    // Flag to throttle detections (prevents duplicate notifications)
    this.detectionPaused = false;
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
      // We're currently scanning; so now we want to stop scanning and look up details.
      // Change the button text to indicate the lookup is in progress.
      scanButton.value = "Looking Up Book Details...";
      // Stop scanning without resetting the button text.
      this.stopScanWithoutResettingButton();
      console.log("Captured ISBNs:", Array.from(this.capturedISBNs));
      
      // If one or more ISBNs were captured, redirect with them.
      if (this.capturedISBNs.size > 0) {
        window.location.href = `${this.urlValue}?isbns=${Array.from(this.capturedISBNs).join(",")}`;
      }
    } else {
      // Start a new scanning session.
      this.capturedISBNs.clear();
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

    // Update the button to reflect that scanning is active.
    scanButton.dataset.scanning = "true";
    scanButton.blur();
    // When scanning is active, we label the button as "Look Up Book Details"
    scanButton.value = "Look Up Book Details";

    Quagga.init(
      {
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

        // Adjust the video element styling after a brief delay.
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
      }
    );

    Quagga.onDetected(this.onDetected.bind(this));
  }

  // This stops scanning and resets the UI, including resetting the button text.
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
      // Revert the button text to the default.
      scanButton.value = "Scan Barcode(s)";
    }
  }

  // This stops scanning without changing the button text.
  stopScanWithoutResettingButton() {
    Quagga.stop();
    const container = document.getElementById("live-scanner-container");
    if (container) {
      container.style.display = "none";
    }
    const scanButton = document.getElementById("scan-button");
    if (scanButton) {
      scanButton.dataset.scanning = "false";
      scanButton.blur();
      // Note: We intentionally do not update scanButton.value here.
    }
  }

  onDetected(result) {
    // If we're in a cooldown period, exit early.
    if (this.detectionPaused) return;

    if (result && result.codeResult && result.codeResult.code) {
      // Remove any non-digit characters.
      const isbn = result.codeResult.code.replace(/[^0-9]/g, "");
      console.log("Detected ISBN:", isbn);
      if (this.isValidISBN(isbn)) {
        // Only add and show notification if the ISBN hasn't already been captured.
        if (!this.capturedISBNs.has(isbn)) {
          this.capturedISBNs.add(isbn);
          this.showNotification(`${isbn} scanned`);
          // Pause further detections briefly to avoid duplicate notifications.
          this.detectionPaused = true;
          setTimeout(() => {
            this.detectionPaused = false;
          }, 1000); // 1-second cooldown period.
        }
      }
    }
  }

  isValidISBN(isbn) {
    return (
      isbn.length === 13 && (isbn.startsWith("978") || isbn.startsWith("979"))
    );
  }

  // Display a temporary notification in the middle of the scanner container.
  showNotification(message) {
    const container = document.getElementById("live-scanner-container");
    if (!container) return;

    // Create a notification element.
    const notification = document.createElement("div");
    notification.textContent = message;

    // Use custom styling for better visibility over a red background.
    notification.classList.add("alert", "alert-info");
    notification.style.position = "absolute";
    notification.style.top = "50%";
    notification.style.left = "50%";
    notification.style.transform = "translate(-50%, -50%)";
    notification.style.zIndex = "1000"; // Ensure it appears above the video.
    notification.style.transition = "opacity 1s ease-out";
    notification.style.opacity = 1;
    notification.style.backgroundColor = "rgba(0, 0, 0, 0.7)"; // Semi-transparent dark background.
    notification.style.color = "#fff"; // White text.
    notification.style.fontSize = "1.5rem"; // Bigger text.
    notification.style.padding = "10px 20px";
    notification.style.borderRadius = "5px";

    // Append the notification to the live scanner container.
    container.appendChild(notification);

    // After a delay, fade out and remove the notification.
    setTimeout(() => {
      notification.style.opacity = 0;
      setTimeout(() => {
        notification.remove();
      }, 1000); // Remove after the transition completes.
    }, 1500); // Display for 1.5 seconds before fading out.
  }
}
