read -p "Press 1 for the current weather or 2 for a five day forecast" num
if [ $num = 1 ]; then
        mode="weather"
elif [ $num = 2 ]; then
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
        info=$(echo $outlook | jq "[ . |  { 
		dt:\"$(date +"%Y-%m-%d %H:%M:%S")\", 
		temp: .main.temp, weather: .weather[0].main, 
			description: .weather[0].description, 
			wind_speed: .wind.speed 
		}]")
	
else
	info=$(echo $outlook | jq "[.list[] | {
		dt: .dt_txt, temp: .main.temp, 
			weather: .weather[0].main, 
			description: .weather[0].description, 
			wind_speed: .wind.speed
		}]")
fi

# Checks length of json array
len=$( echo "$info" | jq length )


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

