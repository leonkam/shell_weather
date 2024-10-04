#!/bin/bash
# Get user information
read -p "Enter your name: " NAME
read -p "Enter your email address: " EMAIL
read -p "Enter your phone number: " PHONE
read -p "Enter your date of birth (YYYY-MM-DD): " DOB
read -p "Enter the location for weather alerts (city): " LOCATION
# Set your OpenWeatherMap API key
API_KEY="28ef72b610f55e4c3687fe60b438ab47"
# OpenWeatherMap API URL for 5-day forecast
URL="https://api.openweathermap.org/data/2.5/forecast?q=$LOCATION&appid=$API_KEY&units=metric"
# OpenWeatherMap API URL for current weather
CURRENT_URL="https://api.openweathermap.org/data/2.5/weather?q=$LOCATION&appid=$API_KEY&units=metric"
# Make the API request and store the response
RESPONSE=$(curl -s "$URL")
CURRENT_RESPONSE=$(curl -s "$CURRENT_URL")
# Check if response is valid
if [[ $? -ne 0 ]]; then
   echo "Error: Unable to retrieve weather data."
   exit 1
fi
# Save the 5-day forecast API response into a JSON file
echo "$RESPONSE" > forecast_data.json
# Save the current weather API response into a JSON file
echo "$CURRENT_RESPONSE" > current_weather_data.json
# Parse weather data for 5-day forecast including humidity, rain, fog, snow
WEATHER_FORECAST=$(echo "$RESPONSE" | jq -r '.list[] | "\(.dt_txt): \(.weather[0].description), Temp: \(.main.temp)°C, Humidity: \(.main.humidity)%, Rain: \(.rain["3h"] // "None"), Snow: \(.snow["3h"] // "None"), Fog: \(.weather[0].description | test("fog")? // "No")"')
# Parse the current weather data including sunrise, sunset, humidity
CURRENT_WEATHER=$(echo "$CURRENT_RESPONSE" | jq -r '"\(.name): \(.weather[0].description), Temp: \(.main.temp)°C, Humidity: \(.main.humidity)%, Sunrise: \(.sys.sunrise | strftime("%H:%M")), Sunset: \(.sys.sunset | strftime("%H:%M"))"')
# Debugging: Print current weather and 5-day forecast to terminal
echo "Current weather:"
echo "$CURRENT_WEATHER"
echo "5-day forecast:"
echo "$WEATHER_FORECAST"
# Check for road alerts based on weather conditions
ROAD_ALERTS=$(echo "$RESPONSE" | jq -r '.list[] | select(.weather[0].main | test("Rain|Snow|Fog")) | "\(.dt_txt): \(.weather[0].description) - Road Alert!"')
# Check if the user's birthday has severe weather conditions
BIRTHDAY_ALERT=$(echo "$RESPONSE" | jq -r --arg DOB "$DOB" '.list[] | select(.dt_txt | startswith($DOB)) | "\(.dt_txt): \(.weather[0].description), Temp: \(.main.temp)°C - Special Birthday Weather Alert!"')
# Create email content
EMAIL_SUBJECT="5-Day Weather Forecast for $LOCATION"
EMAIL_BODY="Hello $NAME,\n\nHere is the current weather for $LOCATION:\n\n$CURRENT_WEATHER\n\nHere is the 5-day weather forecast:\n\n$WEATHER_FORECAST\n\nRoad Alerts:\n$ROAD_ALERTS\n\nBirthday Alert:\n$BIRTHDAY_ALERT\n\nThank you for subscribing to our weather alerts."
# Send the email using sendmail
echo -e "Subject: $EMAIL_SUBJECT\nFrom: weatherforcastalert@gmail.com\nTo: $EMAIL\n\n$EMAIL_BODY" | sendmail -t
echo "Weather forecast sent to $EMAIL."
