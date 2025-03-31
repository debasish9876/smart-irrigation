#include <Firebase_ESP_Client.h>
#include <ESP8266WiFi.h>
#include <DHT.h>
#include <addons/TokenHelper.h>  // Required to get the token info

// Replace with your WiFi credentials
#define WIFI_SSID "sourav"
#define WIFI_PASSWORD "95567757"

// Firebase project credentials
#define DATABASE_URL "temp-c73fd-default-rtdb.firebaseio.com/"
#define API_KEY "AIzaSyC4AddftY_o_dwxlJseY6ct9O_mr8_buhQ"  // Without 'https://'

const char* deviceId = "12345";

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variables
#define DHTPIN D4              // DHT11 data pin connected to GPIO 4
#define DHTTYPE DHT11          // DHT11 sensor type
#define SOIL_MOISTURE_PIN A0   // Analog pin for Soil Moisture Sensor
#define RELAY_PIN D6           // GPIO 12 for Relay (Pump control)
#define SOIL_MOISTURE_THRESHOLD 400  // Threshold to turn on pump

// DHT sensor setup
DHT dht(DHTPIN, DHTTYPE);

// Firebase settings
float waterLimit = 30.0;  // This is a customizable threshold stored on Firebase
bool motorStatus = false; // This will be fetched from Firebase

void connectToWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("Connected to WiFi!");
}

void setup() {
  // Start Serial communication
  Serial.begin(115200);

  // Initialize DHT sensor
  dht.begin();

  // Setup Relay pin
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // Turn off pump initially

  // Setup Firebase config
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  // Firebase authentication (using email/password)
  auth.user.email = "22cse312.debasishmishra@giet.edu";
  auth.user.password = "987654321";

  // Assign the callback function for Firebase token generation
  config.token_status_callback = tokenStatusCallback;  // Optional

  // Connect to WiFi
  connectToWiFi();

  // Initialize Firebase
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // Read temperature and humidity from DHT11
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  // Read soil moisture data
  int soilMoistureValue = analogRead(SOIL_MOISTURE_PIN);

  // Fetch motor status from Firebase (manual control from app)
  if (Firebase.ready()) {
    if (Firebase.RTDB.getBool(&fbdo, "/motorStatus")) {
      motorStatus = fbdo.boolData();
      Serial.print("Motor status from Firebase: ");
      Serial.println(motorStatus ? "ON" : "OFF");
    } else {
      Serial.println(fbdo.errorReason());
    }
  }

  // Control the pump based on soil moisture threshold or motor status from app
  if (motorStatus) { // If the motorStatus is controlled from the app
    digitalWrite(RELAY_PIN, HIGH);  // Turn on the pump
    Serial.println("Pump turned ON by app.");
  } else {
    if (soilMoistureValue > SOIL_MOISTURE_THRESHOLD) {
      digitalWrite(RELAY_PIN, HIGH);  // Turn on the pump
      Serial.println("Soil is dry, turning on the pump...");
    } else {
      digitalWrite(RELAY_PIN, LOW); // Turn off the pump
      Serial.println("Soil moisture is sufficient, turning off the pump.");
    }
  }

  // Print sensor readings to Serial Monitor
  Serial.print("Humidity: ");
  Serial.print(humidity);
  Serial.print("%, Temperature: ");
  Serial.print(temperature);
  Serial.print("°C, Soil Moisture: ");
  Serial.println(soilMoistureValue);

  // Send sensor data to Firebase
  if (Firebase.ready()) {
    if (Firebase.RTDB.setFloat(&fbdo, "/sensors/temperature", temperature)) {
      Serial.println("Temperature uploaded successfully.");
    } else {
      Serial.println(fbdo.errorReason());
    }

    if (Firebase.RTDB.setFloat(&fbdo, "/sensors/humidity", humidity)) {
      Serial.println("Humidity uploaded successfully.");
    } else {
      Serial.println(fbdo.errorReason());
    }

    if (Firebase.RTDB.setInt(&fbdo, "/sensors/soilMoisture", soilMoistureValue)) {
      Serial.println("Soil moisture uploaded successfully.");
    } else {
      Serial.println(fbdo.errorReason());
    }
  }

  // Delay before next reading
  delay(2000); // 2 seconds delay
}
