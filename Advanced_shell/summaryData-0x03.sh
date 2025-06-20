#!/bin/bash

# Summarize Pokemon Data - Task 3
# Read JSON files from Task 2, generate CSV report, and calculate averages
# Uses jq for JSON parsing and awk for calculations

# Configuration
INPUT_DIR="pokemon_data"
OUTPUT_CSV="pokemon_report.csv"
TEMP_FILE="temp_pokemon_data.txt"

# Function to check prerequisites
check_prerequisites() {
    # Check if input directory exists
    if [ ! -d "$INPUT_DIR" ]; then
        echo "Error: Directory '$INPUT_DIR' not found!"
        echo "Please run Task 2 (batch processing) first to generate Pokemon data files."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required but not installed."
        echo "Install with: sudo apt install jq"
        exit 1
    fi
    
    # Check if there are JSON files in the directory
    if ! ls "$INPUT_DIR"/*.json >/dev/null 2>&1; then
        echo "Error: No JSON files found in '$INPUT_DIR'/"
        echo "Please run Task 2 first to generate Pokemon data files."
        exit 1
    fi
}

# Function to extract data from JSON files
extract_pokemon_data() {
    echo "Extracting data from JSON files..."
    
    # Clear temp file
    > "$TEMP_FILE"
    
    # Process each JSON file
    for json_file in "$INPUT_DIR"/*.json; do
        if [ -f "$json_file" ]; then
            # Extract name, height, weight using jq
            pokemon_data=$(jq -r '[.name, .height, .weight] | @tsv' "$json_file" 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$pokemon_data" ]; then
                echo "$pokemon_data" >> "$TEMP_FILE"
            else
                echo "Warning: Failed to extract data from $(basename "$json_file")"
            fi
        fi
    done
    
    # Check if we extracted any data
    if [ ! -s "$TEMP_FILE" ]; then
        echo "Error: No valid data extracted from JSON files."
        exit 1
    fi
}

# Function to generate CSV report
generate_csv_report() {
    echo "Generating CSV report..."
    
    # Create CSV header
    echo "Name,Height (m),Weight (kg)" > "$OUTPUT_CSV"
    
    # Process extracted data and convert units
    awk -F'\t' '{
        name = $1
        height_dm = $2
        weight_hg = $3
        
        # Convert units: decimeters to meters, hectograms to kg
        height_m = height_dm / 10
        weight_kg = weight_hg / 10
        
        # Capitalize first letter of name
        name = toupper(substr(name, 1, 1)) substr(name, 2)
        
        # Output CSV format
        printf "%s,%.1f,%.1f\n", name, height_m, weight_kg
    }' "$TEMP_FILE" | sort >> "$OUTPUT_CSV"
    
    echo "CSV Report generated at: $OUTPUT_CSV"
}

# Function to display CSV content
display_csv_content() {
    echo ""
    cat "$OUTPUT_CSV"
    echo ""
}

# Function to calculate averages using awk
calculate_averages() {
    echo "Calculating averages..."
    
    # Skip header line and calculate averages
    tail -n +2 "$OUTPUT_CSV" | awk -F',' '{
        height_sum += $2
        weight_sum += $3
        count++
    }
    END {
        if (count > 0) {
            avg_height = height_sum / count
            avg_weight = weight_sum / count
            printf "Average Height: %.2f m\n", avg_height
            printf "Average Weight: %.2f kg\n", avg_weight
        } else {
            print "Error: No data to calculate averages"
        }
    }'
}

# Function to show file statistics
show_statistics() {
    local file_count=$(ls "$INPUT_DIR"/*.json 2>/dev/null | wc -l)
    local processed_count=$(tail -n +2 "$OUTPUT_CSV" | wc -l)
    
    echo ""
    echo "Statistics:"
    echo "============="
    echo "JSON files found: $file_count"
    echo "Successfully processed: $processed_count"
    echo "CSV file size: $(du -h "$OUTPUT_CSV" | cut -f1)"
}

# Main execution function
main() {
    echo "Pokemon Data Summary Report Generator"
    echo "======================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Extract data from JSON files
    extract_pokemon_data
    
    # Generate CSV report
    generate_csv_report
    
    # Display the CSV content
    display_csv_content
    
    # Calculate and display averages
    calculate_averages
    
    # Show statistics
    show_statistics
    
    # Cleanup
    rm -f "$TEMP_FILE"
    
    echo ""
    echo "Report generation completed successfully!"
}

# Handle script interruption
trap 'echo ""; echo "Script interrupted. Cleaning up..."; rm -f "$TEMP_FILE"; exit 130' INT

# Run main function
main "$@"