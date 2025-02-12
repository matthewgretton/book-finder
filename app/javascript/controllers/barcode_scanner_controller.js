// app/javascript/controllers/barcode_scanner_controller.js
import { Controller } from "@hotwired/stimulus";
import Quagga from "quagga";

export default class extends Controller {
  static values = { url: String };

  connect() {
    // Use a Map to store unique book details keyed by the scanned ISBN.
    // The stored object will only have the title and author.
    this.capturedBooks = new Map();
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
      // User pressed the button to stop scanning and look up details.
      scanButton.value = "Looking up book details...";
      this.stopScanWithoutResettingButton();
      console.log("Captured Books:", Array.from(this.capturedBooks.values()));

      if (this.capturedBooks.size > 0) {
        // Convert the Map values (which are objects of the form {title, author})
        // to JSON and pass them to the Rails controller.
        const booksArray = Array.from(this.capturedBooks.values());
        window.location.href = `${this.urlValue}?books=${encodeURIComponent(JSON.stringify(booksArray))}`;
      } else {
        scanButton.value = "Scan Barcode(s)";
        alert("No valid book details were captured. Please try scanning again.");
      }
    } else {
      // Start a new scanning session.
      this.capturedBooks.clear();
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

  // Stops scanning and resets the UI (including resetting the button text).
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

  // Stops scanning without changing the button text (used during lookup).
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
    }
  }

  onDetected(result) {
    if (this.detectionPaused) return;

    if (result && result.codeResult && result.codeResult.code) {
      // Remove any non-digit characters.
      const isbn = result.codeResult.code.replace(/[^0-9]/g, '');
      console.log("Detected ISBN:", isbn);
      if (this.isValidISBN(isbn)) {
        if (!this.capturedBooks.has(isbn)) {
          // Pause further detections temporarily.
          this.detectionPaused = true;
          // Call Open Library to get book details.
          fetch(`https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data`)
            .then(response => response.json())
            .then(data => {
              const key = `ISBN:${isbn}`;
              if (data && data[key]) {
                const bookData = data[key];
                const title = bookData.title;
                const author = (bookData.authors && bookData.authors[0].name) || "Unknown Author";
                // Store only the title and author.
                this.capturedBooks.set(isbn, { title: title, author: author });
                // Notify the user with the scanned book title.
                this.showNotification(`Scanned "${title}"`);
              } else {
                console.log("No valid data returned from OpenLibrary for ISBN:", isbn);
              }
            })
            .catch(err => {
              console.error("Error fetching from OpenLibrary:", err);
            })
            .finally(() => {
              setTimeout(() => {
                this.detectionPaused = false;
              }, 1000); // Adjust the pause duration as needed.
            });
        }
      }
    }
  }

  isValidISBN(isbn) {
    return (
      isbn.length === 13 &&
      /^[0-9]+$/.test(isbn) &&
      (isbn.startsWith("978") || isbn.startsWith("979"))
    );
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
    notification.style.width = "80%";          // Use 80% of the container's width.
    notification.style.maxWidth = "800px";       // Allow up to 800px width.
    notification.style.whiteSpace = "normal";    // Allow wrapping normally.
    notification.style.textAlign = "center";     // Center the text.
    
    // Additional styling for improved visibility.
    notification.style.backgroundColor = "rgba(0, 0, 0, 0.7)"; // Semi-transparent dark background.
    notification.style.color = "#fff";                         // White text.
    notification.style.fontSize = "1.5rem";                    // Larger text.
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
