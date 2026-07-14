// Fills in a result row's series and word count, which come from a second
// scrape of the book's detail page and load after the row first renders.
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };
  static targets = ["series", "wordCount"];

  connect() {
    fetch(this.urlValue, { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      })
      .then((details) => {
        if (this.hasSeriesTarget) {
          this.seriesTarget.textContent = details.series || "";
        }
        if (this.hasWordCountTarget) {
          this.wordCountTarget.textContent = details.word_count ?? "";
        }
      })
      .catch((error) => {
        console.error("Failed to load book details:", error);
        if (this.hasSeriesTarget) this.seriesTarget.textContent = "—";
        if (this.hasWordCountTarget) this.wordCountTarget.textContent = "—";
      });
  }
}
