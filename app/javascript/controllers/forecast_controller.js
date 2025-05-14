import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "loading", "error", "result"]

  handleSubmit(event) {
    event.preventDefault();
    const address = this.formTarget.querySelector("input[name='address']").value;

    this.showLoading();
    this.hideError();
    this.hideResult();

    fetch(`/api/v1/forecast.json?address=${encodeURIComponent(address)}`)
      .then(response => {
        if (!response.ok) {
          console.log(response)
          return response.text().then(text => {
            let errorMessage = "Unknown error";
            try {
              const data = JSON.parse(text);
              errorMessage = data.errors ? data.errors.map(e => e.message).join(", ") : "Something went wrong";
            } catch (e) {
              errorMessage = "Invalid server response";
            }
            throw new Error(errorMessage);
          });
        }
        return response.json();
      })
      .then(data => this.showResult(data.data.attributes, data.meta))
      .catch(error => {
        const message = error.message || "An unexpected error occurred";
        this.showError(message);
      })
      .finally(() => this.hideLoading());
  }

  showLoading() {
    this.loadingTarget.style.display = "block"
  }

  hideLoading() {
    this.loadingTarget.style.display = "none"
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.style.display = "block"
  }

  hideError() {
    this.errorTarget.style.display = "none"
  }

  showResult(attributes, meta) {
    const html = `
      <h2>Forecast:</h2>
      <p>Current Temperature: ${attributes.current_temperature}</p>
      <p>High: ${attributes.high_temperature}</p>
      <p>Low: ${attributes.low_temperature}</p>
      <p><strong>Cached: ${meta.cached}</strong></p>
    `
    this.resultTarget.innerHTML = html
    this.resultTarget.style.display = "block"
  }

  hideResult() {
    this.resultTarget.style.display = "none"
  }
}
