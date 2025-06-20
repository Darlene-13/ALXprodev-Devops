#!/bin/dash

# Data Extraction Automation -Task 1
# Extract Pokemon name, height, weight and types from JSON file
# Format output: "Pikachu is of type Electric, weights 6kg and is 0.4m tall"
# Using only: jq, awk sed

JSON_FILE="data.json"

# Check if data,json exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: $JSON_FILE not found."
    echo "Please run the API automation script first to fetch data."
    exit 1
fi

# Extract raw data using jq
echo "Extracting raw dara with jq"
RAW_DATA=$(jq -r '.name + "|" + (.height|tostring) + "|" + (.weight|tostring) + "|" + .types[0].type.name' "$JSON_FILE")

# Use awk to process and calculate conversions
echo "Processing data with awk ......"
PROCESSSED_DATA=$(echo "$RAW_DATA" | awk -F'|''{
    name = $1
    height_dm = $2
    weight_hg = $3
    type = $4

    # Convert height from decimeters to meters by dividing by 10
    height_m = height_dm /10

    # Convert weight from hectograms to kilograms by diving by 10
    weight_kg = weight_hg/10

    #Create a formatted string ouput
    printf "%s|%s|%g|%g", name, type, weight_kg, height_m

}')

# Step 3: Use sed to format the final output with proper capitalization
echo " Formatting with sed ......"
echo "$PROCESSSED_DATA" | sed -E '
      s/^([a-z])/\U\1/;           # Capitalize first letter of name
      s/\|([a-z])/|\U\1/;         # Capitalize first letter of type
      s/([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)/\1 is of type \2, weighs \3kg, and is \4m tall./
'