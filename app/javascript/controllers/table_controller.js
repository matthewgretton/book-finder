import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["table", "wrapper"];

  connect() {
    this.adjustScale();
    window.addEventListener("resize", this.adjustScale.bind(this));
  }

  disconnect() {
    window.removeEventListener("resize", this.adjustScale.bind(this));
  }

  adjustScale() {
    console.log("Adjusting table scale...");
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