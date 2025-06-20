#!/bin/bash

# Batch Pokemon Data Retrieval - Task 2
# Fetch multiple Pokemon data and save to separate files
# Handles rate limiting and provides progress feedback

# Configuration
POKEMON_LIST=("Bulbasaur" "Ivysaur" "Venusaur" "Charmander" "Charmeleon")
OUTPUT_DIR="pokemon_data"
ERROR_FILE="batch_errors.txt"
DELAY_SECONDS=1.5  # Delay between requests to handle rate limiting
BASE_URL="https://pokeapi.co/api/v2/pokemon"
MAX_RETRIES=3      # Maximum retry attempts per Pokemon
RETRY_DELAY=2      # Delay between retry attempts (seconds)

# Function to log errors with timestamp
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$ERROR_FILE"
}

# Function to create output directory
setup_directory() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "📁 Creating directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
        if [ $? -ne 0 ]; then
            echo "Failed to create directory: $OUTPUT_DIR"
            exit 1
        fi
    fi
}

# Function to test with invalid Pokemon (for demonstration)
test_error_handling() {
    echo "🧪 Testing error handling with invalid Pokemon..."
    echo ""
    
    # Test with an invalid Pokemon name
    POKEMON_LIST=("Bulbasaur" "InvalidPokemon" "Charmander")
    
    echo "Testing with: ${POKEMON_LIST[*]}"
    echo " (InvalidPokemon should fail and be skipped)"
    echo ""
}

# Function to fetch single Pokemon data with retry logic
fetch_pokemon() {
    local pokemon_name="$1"
    local pokemon_lower=$(echo "$pokemon_name" | tr '[:upper:]' '[:lower:]')
    local output_file="$OUTPUT_DIR/${pokemon_lower}.json"
    local api_url="$BASE_URL/$pokemon_lower"
    local attempt=1
    
    echo "Fetching data for $pokemon_lower..."
    
    while [ $attempt -le $MAX_RETRIES ]; do
        # Make API request with comprehensive error handling
        HTTP_CODE=$(curl -s -S -w "%{http_code}" \
            --connect-timeout 10 \
            --max-time 30 \
            -o "$output_file" \
            "$api_url" 2>/dev/null)
        
        CURL_EXIT_CODE=$?
        
        # Check curl command success
        if [ $CURL_EXIT_CODE -eq 0 ]; then
            # Extract HTTP status code
            HTTP_STATUS="${HTTP_CODE: -3}"
            
            # Check HTTP status
            case "$HTTP_STATUS" in
                200)
                    # Validate JSON if jq is available
                    if command -v jq >/dev/null 2>&1; then
                        if jq empty "$output_file" >/dev/null 2>&1; then
                            echo "Saved data to $output_file"
                            return 0
                        else
                            log_error "Attempt $attempt: Invalid JSON received for $pokemon_name"
                            rm -f "$output_file"
                            if [ $attempt -eq $MAX_RETRIES ]; then
                                echo "Failed to fetch valid data for $pokemon_lower after $MAX_RETRIES attempts"
                                return 1
                            fi
                        fi
                    else
                        echo "Saved data to $output_file"
                        return 0
                    fi
                    ;;
                404)
                    log_error "Pokemon '$pokemon_name' not found (HTTP 404)"
                    rm -f "$output_file"
                    echo "Pokemon '$pokemon_lower' not found - skipping"
                    return 1
                    ;;
                429)
                    log_error "Attempt $attempt: Rate limited (HTTP 429) for $pokemon_name"
                    rm -f "$output_file"
                    echo "⏳ Rate limited - waiting longer before retry..."
                    sleep $((RETRY_DELAY * 2))  # Longer delay for rate limiting
                    ;;
                5*)
                    log_error "Attempt $attempt: Server error (HTTP $HTTP_STATUS) for $pokemon_name"
                    rm -f "$output_file"
                    echo "Server error (HTTP $HTTP_STATUS) - retrying..."
                    ;;
                *)
                    log_error "Attempt $attempt: HTTP $HTTP_STATUS error for $pokemon_name"
                    rm -f "$output_file"
                    echo "HTTP $HTTP_STATUS error - retrying..."
                    ;;
            esac
        else
            # Handle curl errors
            case "$CURL_EXIT_CODE" in
                6)
                    log_error "Attempt $attempt: Could not resolve host for $pokemon_name"
                    echo "Network error: Could not resolve host - retrying..."
                    ;;
                7)
                    log_error "Attempt $attempt: Failed to connect to API for $pokemon_name"
                    echo "Connection error: Failed to connect - retrying..."
                    ;;
                28)
                    log_error "Attempt $attempt: Request timeout for $pokemon_name"
                    echo "Timeout error: Request took too long - retrying..."
                    ;;
                35)
                    log_error "Attempt $attempt: SSL/TLS error for $pokemon_name"
                    echo "SSL error: Secure connection failed - retrying..."
                    ;;
                *)
                    log_error "Attempt $attempt: Curl error (code $CURL_EXIT_CODE) for $pokemon_name"
                    echo "Network error (code $CURL_EXIT_CODE) - retrying..."
                    ;;
            esac
            rm -f "$output_file"
        fi
        
        # Increment attempt counter
        ((attempt++))
        
        # Wait before next retry (except for last attempt)
        if [ $attempt -le $MAX_RETRIES ]; then
            echo "Waiting ${RETRY_DELAY}s before retry $attempt/$MAX_RETRIES..."
            sleep $RETRY_DELAY
        fi
    done
    
    # All retries failed
    log_error "All $MAX_RETRIES attempts failed for $pokemon_name"
    echo "Failed to fetch data for $pokemon_lower after $MAX_RETRIES attempts - skipping"
    return 1
}

# Main execution function
main() {
    echo "Enhanced Batch Pokemon Data Retrieval with Retry Logic"
    echo "========================================================="
    echo "Pokemon list: ${POKEMON_LIST[*]}"
    echo "Output directory: $OUTPUT_DIR"
    echo "Max retries per Pokemon: $MAX_RETRIES"
    echo "Delay between requests: ${DELAY_SECONDS}s"
    echo "Retry delay: ${RETRY_DELAY}s"
    echo ""
    
    # Initialize
    touch "$ERROR_FILE"
    setup_directory
    
    local total_pokemon=${#POKEMON_LIST[@]}
    local successful=0
    local failed=0
    
    # Process each Pokemon
    for pokemon in "${POKEMON_LIST[@]}"; do
        if fetch_pokemon "$pokemon"; then
            ((successful++))
        else
            ((failed++))
        fi
        
        # Rate limiting delay between different Pokemon (not retries)
        if [ $((successful + failed)) -lt $total_pokemon ]; then
            echo "Waiting ${DELAY_SECONDS}s before processing next Pokemon..."
            sleep "$DELAY_SECONDS"
            echo ""
        fi
    done
    
    # Final summary
    echo ""
    echo "Batch Processing Summary:"
    echo "============================"
    echo "Successfully processed: $successful/$total_pokemon Pokemon"
    echo "Failed after retries: $failed/$total_pokemon Pokemon"
    
    if [ $failed -gt 0 ]; then
        echo "Check $ERROR_FILE for detailed error information"
        echo ""
        echo "Failed Pokemon details:"
        for pokemon in "${POKEMON_LIST[@]}"; do
            local pokemon_lower=$(echo "$pokemon" | tr '[:upper:]' '[:lower:]')
            if [ ! -f "$OUTPUT_DIR/${pokemon_lower}.json" ]; then
                echo "   - $pokemon_lower"
            fi
        done
    fi
    
    echo ""
    if [ $successful -eq $total_pokemon ]; then
        echo "All Pokemon data successfully retrieved!"
    elif [ $successful -gt 0 ]; then
        echo "Partial success: $successful Pokemon retrieved, $failed failed"
        exit 1
    else
        echo "Complete failure: No Pokemon data could be retrieved"
        exit 1
    fi
}

# Handle script interruption
trap 'echo ""; echo "Script interrupted. Partial downloads may be available in $OUTPUT_DIR/"; exit 130' INT

# Handle command line arguments
if [ "$1" = "--test-errors" ]; then
    test_error_handling
fi

# Run main function
main "$@"