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

###############################################################################


FILE_NAME='weather_forecast.csv'

# Queries the JSON for the relevant data using jq
weather_info=$(echo $RESPONSE | jq "[.list[] | {
        dt: .dt_txt, temp: .main.temp,
                weather: .weather[0].main,
                description: .weather[0].description,
                wind_speed: .wind.speed
        }]")

# Checks length of json array
len=$( echo "$weather_info" | jq length )
# Creates csv database of weather forecast
echo "date,time,temp,weather,description,wind_speed,task" > $FILE_NAME
# Loops through json array
for i in $(seq 0 $((len-1))); do
	# Converts
        dt=$(echo "$weather_info" | jq -r ".[$i].dt")
        temp=$(echo "$weather_info" | jq -r ".[$i].temp")
        weather=$(echo "$weather_info" | jq -r ".[$i].weather")
        description=$(echo "$weather_info" | jq -r ".[$i].description")
        wind_speed=$(echo "$weather_info" | jq -r ".[$i].wind_speed")
        date=$(date -d "$dt" "+%A %d %B")
        time=$(date -d "$dt" "+%H:%M")

        # Writes line to csv database
        echo "$date,$time,$temp,$weather,$description,$wind_speed," >> $FILE_NAME
done


display_forecast() {
        echo "Do you want to see the five day forecast or check a particular day?"
        read -p "Press 1 or 2 respectively.   " n
        if [ $n = 1 ]; then
                # Reads the CSV and prints each line that corresponds to morning and night.
                while IFS=, read -r date time temp weather description wind_speed task; do
                        if [[ $time == "09:00" ]] || [[ $time == "18:00" ]]; then
                                echo "===================================="
                                echo $date
                                echo $time
                                echo "The temperature is $temp C."
                                echo "The weather is $weather, with $description."
                                echo "The wind speed is $wind_speed mph."
                                echo $task
                        fi
                done < $FILE_NAME
        else
                echo "Today and the next 4 days are available."
                read -p "Please enter the day of the week you want to see?   " day
                # Transforms day to title case
                day_tc=$(echo "$day" | sed "s/.*/\L&/; s/^./\U&/")
                match=false
                while IFS=, read -r date time temp weather description wind_speed task; do
                        # If the selected day matches line of CSV it gets printed.
                        if [[ "$date" == "$day_tc"* ]]; then
                                match=true
                                echo "===================================="
                                echo $date
                                echo $time
                                echo "The temperature is $temp C."
                                echo "The weather is $weather, with $description."
                                echo "The wind speed is $wind_speed mph."
                                echo $task
                        fi
                done < $FILE_NAME

                # If day was incorrect or unavailable, prints an appropriate message.
                if [ $match = false ]; then
                        echo "The day {$day_tc} is unavailable."
                fi
        fi
}

# Allows functions to be repeated
while true; do
        echo
        echo "Do you want to see the weather forecast, add a task, or exit?"
        read -p "Press 1, 2, or 3 respectively.   " num
        if [ $num = 1 ]; then
                display_forecast
        elif [ $num = 2 ]; then
                break
        elif [ $num = 3 ]; then
                exit 0
        fi
done 


################################################################################################


# Function to convert date from dd.mm.yyyy to full format
convert_date() {
        input_date=$1
# Break down the dd.mm.yyyy format into separate variables
        day=$(echo $input_date | cut -d. -f1)
        month=$(echo $input_date | cut -d. -f2)
        year=$(echo $input_date | cut -d. -f3)

# Use the correct format for the 'date' command to convert it to full date format
        formatted_date=$(date -d "$year-$month-$day" "+%A %d %B")
        echo "$formatted_date"
}

# Function to convert date to a comparison-friendly format (yyyy-mm-dd)
convert_date_for_comparison() {
        input_date=$1
        day=$(echo $input_date | cut -d. -f1)
        month=$(echo $input_date | cut -d. -f2)
        year=$(echo $input_date | cut -d. -f3)

# Convert to yyyy-mm-dd format for comparison
        echo $(date -d "$year-$month-$day" +%s)
}

# Function to check if the entered date is within the next 5 days
check_date_within_range() {
        input_date=$1
# Convert the input date to seconds since epoch
        input_seconds=$(convert_date_for_comparison "$input_date")

# Get the current date and the limit date (current date + 5 days)
        current_seconds=$(date +%s)
        limit_seconds=$(date -d "+5 days" +%s)

# Compare the dates in day format
        if [[ $input_seconds -ge $current_seconds && $input_seconds -le $limit_seconds ]]; then
                return 0  # Valid date
        else
                return 1  # Invalid date
        fi
}


# Show calendar and prompt the user to select a day
echo -e "\nHere is the current calendar:"
#cal
#
# Ask user for date in dd.mm.yyyy format, and validate that it’s within +5 days
while true; do
        echo -e "\nPlease enter the date in format dd.mm.yyyy (e.g., 05.10.2024): "
        read entered_date

# Check if the entered date is valid
        if check_date_within_range "$entered_date"; then
                selected_day=$(convert_date "$entered_date")  # Convert date to full format
                break  # Exit loop if date is valid
        else
                echo "Invalid date. Please enter a date within the next 5 days."
        fi
done

echo "Please enter the time (e.g., 15:00) you want to add a task for: "
read selected_time
# Prompt the user to enter the task
echo "Please enter the task: "
read task


# Function to check if the date and time exist in the CSV
check_date_time_exists() {
        local day="$1"
        local time="$2"
        grep -q "^$day,$time" weather_forecast.csv
}

# If the date and time exist, add the task; otherwise, add a new row with only the date, time, and task
if check_date_time_exists "$selected_day" "$selected_time"; then
# Add task to the existing date and time
        sed -i "/^$selected_day,$selected_time/s/$/ $task/" weather_forecast.csv
        echo "Task added successfully to $selected_day at $selected_time!"
else
# Add new row with the date, time, and task
        echo "$selected_day,$selected_time,,,,,,$task" >> weather_forecast.csv
        echo "New entry created and task added for $selected_day at $selected_time."
fi

~
