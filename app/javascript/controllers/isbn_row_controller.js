// Placeholder row for a scanned ISBN: kicks off the lookup as soon as it
// appears and swaps itself for the result rows via a Turbo Stream.
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };

  connect() {
    fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.text();
      })
      .then((html) => window.Turbo.renderStreamMessage(html))
      .catch((error) => {
        console.error("ISBN lookup failed:", error);
        this.element.innerHTML =
          '<td colspan="7" style="text-align: center;">Lookup failed — try again</td>';
      });
  }
}
