# Weather Forecast Application
[weather_app.webm](https://github.com/user-attachments/assets/c6cf04cb-42aa-43a3-9565-395e86900fdf)

This Ruby on Rails application provides a simple interface to fetch and display weather forecasts for a given US address. It leverages external APIs for geocoding addresses and retrieving weather data, incorporating caching mechanisms for performance and demonstrating best practices in error handling, testing, and code organization.

## Table of Contents

- [Core Concepts and Design](#core-concepts-and-design)
  - [Object Decomposition](#object-decomposition)
  - [Design Patterns and Principles](#design-patterns-and-principles)
- [Scalability Considerations](#scalability-considerations)
- [Setup Instructions](#setup-instructions)
- [Running Tests](#running-tests)
- [Running the Application](#running-the-application)
- [Pull Request History & Rationale](#pull-request-history--rationale)

## Core Concepts and Design

The application is designed with a service-oriented architecture in mind, separating concerns into distinct layers:

1.  **API Clients (`app/services/clients`)**: Responsible for interacting with external APIs (Google Geocoding, Census Geocoding, OpenWeatherMap).
    - A `BaseClient` provides common functionality like making HTTP requests (using Faraday), default timeouts, basic error handling, and logging.
    - Specific clients (e.g., `Clients::Geocoders::GoogleClient`, `Clients::Weather::OpenWeatherMapClient`) inherit from `BaseClient` and implement service-specific logic for request parameters and response parsing.
2.  **Services (`app/services`)**: Orchestrate business logic.
    - `Geocoding::GeocodeService`: Takes an address and uses a geocoding client to return a `Location` object.
    - `Weather::ForecastService`: Takes a `Location` object and uses a weather client to return forecast data. It also implements caching for forecast results.
3.  **Models (`app/models`)**: Represent core data structures. These are plain Ruby objects (`PORO`) including `ActiveModel::Model` and `ActiveModel::Attributes` for validations and attribute handling, not ActiveRecord models as no database persistence is implemented for these in the current scope.
    - `Location`: Stores geocoded information (latitude, longitude, zip code, etc.).
    - `Forecast`: Stores weather forecast details (temperatures, conditions).
    - `Temperature`: A value object representing temperature with its unit.
4.  **Forms (`app/forms`)**: Handle input validation and sanitization.
    - `ForecastQueryForm`: Validates and cleans the address input by the user.
5.  **Controllers (`app/controllers`)**: Handle HTTP requests and responses.
    - `Api::V1::BaseController`: Provides common error handling for all V1 API controllers.
    - `Api::V1::ForecastsController`: Exposes the endpoint to get weather forecasts. It uses the `ForecastQueryForm`, `GeocodeService`, and `ForecastService`.
    - `PagesController`: Serves the main HTML page.
6.  **Presenters (`app/presenters`)**: Format data for the views/API responses.
    - `ForecastPresenter`: Structures the forecast data for the JSON API response, adhering to a consistent format (inspired by JSON:API).
7.  **Error Handling (`app/lib/errors.rb`)**: A custom error hierarchy allows for specific error handling and consistent error responses.
8.  **Frontend (`app/javascript/controllers`, `app/views`)**:
    - A Stimulus controller (`forecast_controller.js`) manages the user interaction on the home page, making asynchronous calls to the backend API and updating the DOM with results, loading states, or errors.
    - The home page (`pages/home.html.erb`) contains the form and elements for displaying data.
    - SimpleCSS V2 is used for basic styling.

### Object Decomposition

- **Address Input & Validation**:
  - `PagesController` -> `home.html.erb` (UI Form)
  - `forecast_controller.js` (Stimulus: captures input, calls API)
  - `Api::V1::ForecastsController`: Receives API request.
  - `ForecastQueryForm`: Validates and sanitizes the address string.
- **Geocoding Process**:
  - `Api::V1::ForecastsController` -> `Geocoding::GeocodeService`
  - `Geocoding::GeocodeService`: Orchestrates geocoding, selects a geocoding client (defaults to Google).
  - `Clients::Geocoders::GoogleClient` (or `Clients::Geocoders::CensusClient`): Inherits from `Clients::BaseClient`.
    - `Clients::BaseClient`: Handles HTTP communication (Faraday), caching (Rails.cache), basic response processing, and network error handling.
    - Specific Client: Formats request, parses response specific to the geocoding provider.
  - `Location` (Model): Stores the structured result from the geocoding client.
- **Weather Fetching Process**:
  - `Api::V1::ForecastsController` -> `Weather::ForecastService`
  - `Weather::ForecastService`: Orchestrates weather fetching, handles caching of weather data.
  - `Clients::Weather::OpenWeatherMapClient`: Inherits from `Clients::BaseClient`.
    - `Clients::BaseClient`: As above.
    - `OpenWeatherMapClient`: Formats request, parses response from OpenWeatherMap API.
  - `Forecast` (Model): Stores structured weather data.
  - `Temperature` (Model): Represents temperature values with units.
- **API Response Generation**:
  - `Api::V1::ForecastsController` -> `ForecastPresenter`
  - `ForecastPresenter`: Formats the `Forecast` object and caching status into a JSON structure.
  - `Api::V1::BaseController`: Handles rescuing from custom errors and rendering standardized JSON error responses.
- **Error Management**:
  - `Errors` (Module with custom error classes like `NotFoundError`, `ExternalApiError`, `InvalidInputError`): Standardized error objects.
  - `Clients::BaseClient`: Catches Faraday errors and wraps them in custom error types (e.g., `Errors::NetworkError`, `Errors::ExternalApiError`).
  - Services & Clients: Raise specific custom errors based on API responses or validation failures.
  - `Api::V1::BaseController`: Rescues from these custom errors to provide user-friendly JSON error messages.

### Design Patterns and Principles

- **Service Objects**: Business logic is encapsulated in service objects (e.g., `GeocodeService`, `ForecastService`) promoting single responsibility and testability.
- **Form Objects**: `ForecastQueryForm` encapsulates validation and sanitization logic for user input, keeping controllers lean.
- **Presenter Pattern**: `ForecastPresenter` is used to format data for the API response, separating presentation logic from controllers and models.
- **Client Abstraction (`BaseClient`)**: Provides a common interface and shared functionality for interacting with different external APIs. This is a form of the **Adapter** or **Gateway** pattern.
- **Strategy Pattern (Implicit)**: The `GeocodeService` and `ForecastService` can accept different client implementations, allowing for easy swapping of API providers if needed (though currently hardcoded to default clients).
- **SOLID Principles**:
  - **Single Responsibility Principle (SRP)**: Each class (client, service, model, controller, presenter, form object) has a distinct responsibility.
  - **Open/Closed Principle (OCP)**: The `BaseClient` and service structure allow for adding new API clients or geocoding/weather services with minimal changes to existing code.
  - **Liskov Substitution Principle (LSP)**: Different geocoding clients, if designed to share a common interface beyond `geocode(address:)`, could be substituted.
  - **Interface Segregation Principle (ISP)**: Clients and services expose focused interfaces.
  - **Dependency Inversion Principle (DIP)**: Services depend on abstractions (client interfaces, though not strictly defined as Ruby interfaces) rather than concrete implementations, allowing for dependency injection (e.g., `client:` parameter in service calls).
- **KISS (Keep It Simple, Stupid)**: The solution aims for clarity and avoids over-engineering for the given requirements.
- **DRY (Don't Repeat Yourself)**: `BaseClient` centralizes common API interaction logic. `Api::V1::BaseController` centralizes API error handling.
- **Custom Error Hierarchy**: Provides a structured way to handle and report errors.
- **Caching**: Implemented at both the geocoding client level (for geocoding results) and the weather service level (for forecast results) to improve performance and reduce external API calls.
- **Configuration Management**: API keys are managed using Rails credentials.
- **Testing**: Comprehensive unit and request specs are provided, using VCR to mock HTTP interactions for reliability and speed.

## Scalability Considerations

- **Background Jobs**: For high-volume requests or slow external APIs, geocoding and weather fetching could be moved to background jobs (e.g., using Sidekiq with the existing `solid_queue` adapter) to prevent blocking web requests and improve user experience. The frontend would then poll for results or use WebSockets.
- **Rate Limiting**: If external API rate limits become an issue, implementing rate limiting on our API and potentially more sophisticated queuing or backoff strategies for external calls would be necessary.
- **Client-Side Caching**: The frontend could implement more aggressive caching of results in `localStorage` or `sessionStorage` to reduce redundant calls for the same address within a user session.
- **Database Persistence**: If historical data or user-specific data were required, introducing a database (e.g., PostgreSQL) would be essential. The current `Location`, `Forecast`, and `Temperature` models are POROs and would be converted to ActiveRecord models.
- **Load Balancing**: Standard for any web application, distributing traffic across multiple application instances.
- **CDN for Assets**: Using a CDN for static assets (JavaScript, CSS) can improve load times for users.
- **API Versioning**: The API is already namespaced (`/api/v1/`), which is good practice for future iterations.
- **Circuit Breaker Pattern**: For external API integrations, a circuit breaker (e.g., using a gem like `resilient_http` or `stoplight`) could prevent cascading failures if an external service becomes unstable.
- **Read Replicas**: If a database is introduced and read load becomes high, read replicas can offload query pressure from the primary database.

## Setup Instructions

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/Alexkarpov878/weather_app.git
    cd weather_app
    ```

2.  **Install Ruby version:**
    Ensure you have Ruby installed. I recommend using asdf for version management.

    ```bash
    # Install asdf if you don't have it
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.2

    # Add to your shell
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
    echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
    # Or for zsh
    # echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.zshrc
    # echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc

    # Install Ruby plugin and the required version
    asdf plugin add ruby
    asdf install ruby 3.4.3
    asdf local ruby 3.4.3
    ```

3.  **Install Bundler:**

    ```bash
    gem install bundler -v 2.6.7
    ```

4.  **Install dependencies:**

    ```bash
    bundle install
    ```

5.  **Set up credentials:**
    The application requires API keys for Google Geocoding and OpenWeatherMap.

    - Run `bin/rails credentials:edit` to open the encrypted credentials file.
    - Add the following structure with your actual API keys:

      ```yml
      geocoder_api_keys:
        google_api_key: YOUR_GOOGLE_GEOCODING_API_KEY

      weather_api_keys:
        open_weather_map: YOUR_OPENWEATHERMAP_API_KEY
      ```

    - Save and close the editor. This will generate/update `config/credentials.yml.enc` and `config/master.key`. **Ensure `config/master.key` is in your `.gitignore` and never committed to the repository if it's not already.** (It should be by default in new Rails apps).

6.  **Database Setup (if applicable in future):**
    Currently, the application primarily uses external APIs and caching, and the default SQLite setup for Rails is present but not actively used for the core weather feature. If a database were used for persistence:

    ```bash
    bin/rails db:create
    bin/rails db:migrate
    ```

7.  **Start the application:**

    ```bash
    # Start the Rails server
    bin/rails server

    # Or use the shorthand
    bin/rails s
    ```

    Once the server is running, open your browser and navigate to `http://localhost:3000` to access the weather application.

## Running Tests

The project uses RSpec for testing. VCR is used to record and replay HTTP interactions with external APIs, making tests faster and more reliable.

To run all tests:

```bash
bundle exec rspec
```

To run tests and have Guard automatically re-run them on file changes (along with Rubocop for linting):

```bash
bundle exec guard
```

VCR cassettes are stored in `spec/fixtures/vcr_cassettes`. If you change an API interaction or add a new one, you might need to delete the relevant cassette and re-run the test to record a new interaction (ensure your API keys are correctly set up in `credentials.yml.enc`).

## Running the Application

1.  **Start the Rails server:**
    ```bash
    bin/rails server
    ```
2.  Open your browser and navigate to `http://localhost:3000`.

You should see the home page with a form to enter a US address.

## Pull Request History & Rationale

Here's a summary of the key pull requests that built this application:

1.  **PR#1: Prep - Install RSpec, Rubocop, Guard, and VCR**

    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/1](https://github.com/Alexkarpov878/weather_app/pull/1)
    - **Summary:** This foundational PR set up the development and testing environment. It integrated RSpec for unit and integration testing, Rubocop for enforcing Ruby style guidelines, Guard for automating test execution and linting upon file changes, and VCR for recording and replaying HTTP interactions, crucial for testing API integrations reliably.
    - **Rationale:** Establishing a robust testing and linting framework from the outset is paramount for maintaining code quality, consistency, and developer productivity. Guard enhances the development workflow, while VCR ensures tests involving external APIs are fast, deterministic, and don't rely on live external services during test runs.

2.  **PR#2: Add Geocoding API Clients & BaseClient**

    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/2](https://github.com/Alexkarpov878/weather_app/pull/2)
    - **Summary:** This PR introduced the core components for interacting with external geocoding services. A `BaseClient` was created to encapsulate common API request logic, error handling, and caching. Specific clients for Google Geocoding and Census Geocoding were implemented, along with a `Location` model to represent address data and a comprehensive set of custom error classes for better error management.
    - **Rationale:** The `BaseClient` promotes DRY principles and makes it easier to add new API clients. Dedicated client classes for each service encapsulate service-specific details. Custom errors improve debugging and allow for more granular error handling downstream. The `Location` model provides a structured way to handle geocoded data.

3.  **PR#3: Implement OpenWeatherMap client and enhance error handling**

    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/3](https://github.com/Alexkarpov878/weather_app/pull/3)
    - **Summary:** This PR added the capability to fetch weather forecasts by implementing a client for the OpenWeatherMap API. It also introduced `Forecast` and `Temperature` models to structure the weather data. Further refinements were made to the `BaseClient`'s error handling, especially around logging and differentiating HTTP error statuses.
    - **Rationale:** Adding the OpenWeatherMap client is a core step towards the application's primary goal. The new models ensure that weather data is handled in a structured and predictable manner. Continuous improvement of error handling in the `BaseClient` increases the application's resilience.

4.  **PR#4: Add Weather Forecast API Endpoint with Geocoding, Error Handling, and Caching**

    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/4](https://github.com/Alexkarpov878/weather_app/pull/4)
    - **Summary:** This PR integrated the geocoding and weather fetching functionalities into a public API endpoint (`/api/v1/forecast`). It introduced a `ForecastQueryForm` for input validation, a `ForecastPresenter` for formatting API responses, and implemented caching for weather forecast data at the service layer. A `BaseController` was added for common API error responses and logging. Rubocop configurations were also updated.
    - **Rationale:** Creating the API endpoint is the central piece that allows clients (including the application's own frontend) to consume the weather forecast feature. The form object ensures data integrity, the presenter separates concerns for response formatting, service-level caching optimizes performance, and the base controller standardizes API error handling and logging.

5.  **PR#5: Implement Weather Forecast Feature with Stimulus Controller and API Integration**
    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/5](https://github.com/Alexkarpov878/weather_app/pull/5)
    - **Summary:** This PR delivered the user interface. A `PagesController` was added to serve the home page, which includes an address input form. A Stimulus JavaScript controller (`forecast_controller.js`) was implemented to handle form submissions asynchronously, call the backend API, and dynamically update the page with the forecast, loading indicators, or error messages. Basic styling was applied using SimpleCSS 2.
    - **Rationale:** This PR makes the application usable from a web browser. Stimulus provides a lightweight and efficient way to add interactivity to the frontend without the overhead of a larger JavaScript framework, fitting the "modest JavaScript framework" philosophy of Hotwire. Asynchronous API calls enhance the user experience by avoiding full page reloads.

6.  **PR#6: Improve API Error Handling and Client Robustness**
    - **Link:** [https://github.com/Alexkarpov878/weather_app/pull/5](https://github.com/Alexkarpov878/weather_app/pull/7)
    - **Summary:** This PR enhances API error handling and refines geocoding/weather clients for better maintainability and reliability. Key changes include unified error handling in BaseController, modularized request handling in BaseClient, improved error mapping and caching in GoogleClient, refined input validation in OpenWeatherMapClient, updated error classes, and testing/config updates.
    - **Rationale:**  These improvements reduce code duplication, enhance extensibility, and improve test reliability, aligning with Rails best practices and clean code principles.
