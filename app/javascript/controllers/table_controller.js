import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["table", "wrapper"];

  connect() {
    this.boundAdjustScale = this.adjustScale.bind(this);
    this.adjustScale();
    window.addEventListener("resize", this.boundAdjustScale);

    // Rows stream in after initial render (ISBN lookups, detail fills), so
    // re-scale whenever the table's contents change.
    this.observer = new MutationObserver(this.boundAdjustScale);
    this.observer.observe(this.tableTarget, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  }

  disconnect() {
    window.removeEventListener("resize", this.boundAdjustScale);
    if (this.observer) this.observer.disconnect();
  }

  adjustScale() {
    const table = this.tableTarget;
    const wrapper = this.wrapperTarget;

    // Ensure wrapper is full width
    wrapper.style.width = "100%";
    
    const tableWidth = table.offsetWidth;
    const wrapperWidth = wrapper.offsetWidth;

    if (tableWidth > wrapperWidth) {
      const scale = wrapperWidth / tableWidth;
      table.style.transform = `scale(${scale})`;
      table.style.transformOrigin = "top left";
      wrapper.style.height = `${table.offsetHeight * scale}px`;
    } else {
      // When not scaling down, ensure table takes full width
      table.style.transform = "scale(1)";
      table.style.width = "100%";
      wrapper.style.height = "auto";
    }
  }
}