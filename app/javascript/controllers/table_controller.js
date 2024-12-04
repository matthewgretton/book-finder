import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["table", "wrapper"];

  connect() {
    console.log("TableController connected!");
    console.log("Table Target:", this.tableTarget);
    console.log("Wrapper Target:", this.wrapperTarget);
    this.adjustScale();
    window.addEventListener("resize", this.adjustScale.bind(this));
  }

  disconnect() {
    console.log("TableController disconnected!");
    window.removeEventListener("resize", this.adjustScale.bind(this));
  }

  adjustScale() {
    console.log("Adjusting table scale...");
    const table = this.tableTarget;
    const wrapper = this.wrapperTarget;

    const tableWidth = table.offsetWidth;
    const wrapperWidth = wrapper.offsetWidth;

    console.log(`Table width: ${tableWidth}, Wrapper width: ${wrapperWidth}`);

    if (tableWidth > wrapperWidth) {
      const scale = wrapperWidth / tableWidth;
      console.log(`Scaling table to: ${scale}`);
      table.style.transform = `scale(${scale})`;
      table.style.transformOrigin = "top left";
    } else {
      console.log("No scaling needed");
      table.style.transform = "scale(1)";
    }
  }
}
