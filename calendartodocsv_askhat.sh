read -p "Press 1 for the current weather or 2 for a five day forecast" num
modes=("weather" "forecast")
if [ $num == 1 ]; then
	mode="weather"
elif [ $num == 2 ]; then
	mode="forecast"
fi

 
API_KEY="18a1bffb4847fb5627bea7c521d471f2"
location="london"
geoloc=$(curl -s "http://api.openweathermap.org/geo/1.0/direct?q=$location&appid=$API_KEY" | jq ".[0]")
lat=$(echo $geoloc | jq ".lat")
lon=$(echo $geoloc | jq ".lon")
outlook=$(curl -s "https://api.openweathermap.org/data/2.5/$mode?lat=$lat&lon=$lon&appid=$API_KEY&units=metric" | jq ".")

# Checks mode then queries the json for the relevant data
if [ $mode = "weather" ]; then
	info=$(echo $outlook | jq "[ . |  { dt:\"$(date +"%Y-%m-%d %H:%M:%S")\", temp: .main.temp, weather: .weather[0].main, description: .weather[0].description, wind_speed: .wind.speed }]")
        else
                info=$(echo $outlook | jq "[.list[] | {dt: .dt_txt, temp: .main.temp, weather: .weather[0].main, description: .weather[0].description, wind_speed: .wind.speed}]")

fi

len=$(echo "$info" | jq length)

# Creates csv database of weather forecast
echo "date,time,temp,weather,description,wind_speed,task" > weather_forecast.csv
# Loops through json array
for i in $(seq 0 $((len-1))); do
	dt=$(echo "$info" | jq -r ".[$i].dt")
        temp=$(echo "$info" | jq -r ".[$i].temp")
       	weather=$(echo "$info" | jq -r ".[$i].weather")
       	description=$(echo "$info" | jq -r ".[$i].description")
       	wind_speed=$(echo "$info" | jq -r ".[$i].wind_speed")
        date=$(date -d "$dt" "+%A %d %B")
        time=$(date -d "$dt" "+%H:%M")

# Writes line to csv database
	echo "$date,$time,$temp,$weather,$description,$wind_speed," >> weather_forecast.csv
done

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
cal
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

