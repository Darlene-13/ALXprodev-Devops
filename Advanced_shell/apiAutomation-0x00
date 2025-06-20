
#!/bin/bash

# API Request Automation - Task 0
# Fetches Pikachu data from Pokemon API and saves to data.json
# Logs errors to errors.txt if request fails

# API endpoint for Pikachu
API_URL="https://pokeapi.co/api/v2/pokemon/pikachu"
OUTPUT_FILE="data.json"
ERROR_FILE="errors.txt"

# Function to log errors with timestamp
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$ERROR_FILE"
}

# Function to make the API request
fetch_pokemon_data(){
    echo " Fecthing Pikachu data from Pokemon  API ......"
    # Make API request with curl
    # -s : silent mode (no progress bar)
    # -S: show errors even in silent mode
    # -w: write response code to check success
    # --connect-timeout: timeout for connection
    # --max-time: maximum time for entire operation


    HTTP_CODE=$(curl -s -S -w "%{http_code}" \
        --connect-timeout 10 \
        --max-time 30 \
        -o "$OUTPUT_FILE" \
        "$API_URL" 2>&1)
    
    # Check out if the curl command was successful
    CURL_EXIT_CODE=$?

    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_error "Curl command failed with exit code $CURL_EXIT_CODE"
        log_error "Failed to connect to Pokemon API ar $API_URL"
        return 1
    fi 

    #Extract HTTP status code (last 3 characters of the response)
    HTTP_STATUS="${HTTP_CODE: -3}"

    # Check the HTTP STATUS code
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo  "Successfully fetched Pikachu data."
        echo: "Data saved to $OUTPUT_FILE"
        #Verify that the JSON file is valid
        if command - jq >/dev/null 2>&1; then
            if ! jq empt "$OUTPUT_FILE" >/dev/null 2>&1; then
                log_error "Invalid JSON receive from API"
                return 1
            fi 
        fi 

        # Show the file size
        FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "File size: $FILE_SIZE"
        return 0
    else
        log_error "API request failed with HTTP status code $HTTP_CODE"
        log_error "URL: $URL_API"
        echo "API request failed with status code $HTTP_STATUS"
        echo " Erro logged to: $ERROR_FILE"
        return 1
    fi
        
}

#Main execution
main() {
    echo "Pokemon API Automation Script"
    echo "============================"

    # Create error file if it does not exist
    touch "$ERROR_FILE"

    #Remove existing data file to ensure fresh fetch
    if [ -f "$OUTPUT_FILE" ]; then
        rm "$OUTPUT_FILE"
    fi 
     # Fetch the data
    if fetch_pokemon_data; then
        echo "Script completed successfully."
        
        # Show the content preview if jq is available
        if command -v js>/dev/null 2>&1; then
            echo "Preview of the fetched data:"
            echo "========================="
            jq '.name, .height, .weight, .types[].type.name' "$OUTPUT_FILE" 2>/dev/null || echo "Unable to preview data"
        else
            echo " Install 'jq' for JSON formatting and preview"
        fi
    else
        echo ""
        echo "Script failed. Check $ERRO_FILE for error details."
        exit 1
    fi
}

# Run the main function
main "@"