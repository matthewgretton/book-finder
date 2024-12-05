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

    const tableWidth = table.offsetWidth;
    const wrapperWidth = wrapper.offsetWidth;

    if (tableWidth > wrapperWidth) {
      const scale = wrapperWidth / tableWidth;
      table.style.transform = `scale(${scale})`;
      table.style.transformOrigin = "top left";
      
      // Add this line to adjust the wrapper height
      wrapper.style.height = `${table.offsetHeight * scale}px`;
    } else {
      table.style.transform = "scale(1)";
      // Reset the wrapper height when no scaling is needed
      wrapper.style.height = "auto";
    }
  }
}