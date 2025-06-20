#!/bin/bash

# Parallel Pokemon Data Fetching - Task 5
# Speed up data retrieval using background processes and parallel execution
# Fetches multiple Pokemon data simultaneously for improved performance

# Configuration
POKEMON_LIST=("Bulbasaur" "Ivysaur" "Venusaur" "Charmander" "Charmeleon")
OUTPUT_DIR="pokemon_data"
ERROR_FILE="parallel_errors.txt"
BASE_URL="https://pokeapi.co/api/v2/pokemon"
MAX_CONCURRENT=5   # Maximum concurrent processes
TIMEOUT=30         # Timeout per request in seconds

# Arrays to track parallel processes
declare -a PIDS=()           # Process IDs
declare -a POKEMON_NAMES=()  # Pokemon names for each PID
declare -a RESULTS=()        # Results for each process

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to log errors with timestamp
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$ERROR_FILE"
}

# Function to create output directory
setup_directory() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Creating directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
        if [ $? -ne 0 ]; then
            echo "Failed to create directory: $OUTPUT_DIR"
            exit 1
        fi
    fi
}

# Function to fetch single Pokemon data (runs in background)
fetch_pokemon_parallel() {
    local pokemon_name="$1"
    local pokemon_lower=$(echo "$pokemon_name" | tr '[:upper:]' '[:lower:]')
    local output_file="$OUTPUT_DIR/${pokemon_lower}.json"
    local temp_file="$OUTPUT_DIR/.${pokemon_lower}.tmp"
    local status_file="$OUTPUT_DIR/.${pokemon_lower}.status"
    local api_url="$BASE_URL/$pokemon_lower"
    local pid=$$
    
    # Create status file to track progress
    echo "STARTED" > "$status_file"
    
    # Make API request with timeout
    if curl -s -S --connect-timeout 10 --max-time "$TIMEOUT" \
        -o "$temp_file" "$api_url" 2>/dev/null; then
        
        # Validate JSON if jq is available
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$temp_file" >/dev/null 2>&1; then
                mv "$temp_file" "$output_file"
                echo "SUCCESS:$pokemon_lower" > "$status_file"
                exit 0
            else
                log_error "Invalid JSON received for $pokemon_name (PID: $pid)"
                echo "FAILED:Invalid JSON" > "$status_file"
                rm -f "$temp_file"
                exit 1
            fi
        else
            mv "$temp_file" "$output_file"
            echo "SUCCESS:$pokemon_lower" > "$status_file"
            exit 0
        fi
    else
        local curl_exit=$?
        log_error "Failed to fetch $pokemon_name (PID: $pid, Exit: $curl_exit)"
        echo "FAILED:Network error (code: $curl_exit)" > "$status_file"
        rm -f "$temp_file"
        exit 1
    fi
}

# Function to start parallel processes
start_parallel_fetches() {
    echo "Starting parallel fetch processes..."
    echo "Max concurrent processes: $MAX_CONCURRENT"
    echo "Timeout per request: ${TIMEOUT}s"
    echo ""
    
    local process_count=0
    
    for pokemon in "${POKEMON_LIST[@]}"; do
        # Start background process
        fetch_pokemon_parallel "$pokemon" &
        local pid=$!
        
        # Store PID and pokemon name
        PIDS+=($pid)
        POKEMON_NAMES+=("$pokemon")
        
        echo "Started fetch for $(echo $pokemon | tr '[:upper:]' '[:lower:]') (PID: $pid)"
        
        ((process_count++))
        
        # Limit concurrent processes
        if [ $process_count -ge $MAX_CONCURRENT ]; then
            echo "Reached max concurrent limit, waiting for some to complete..."
            wait_for_some_completion
            process_count=$(count_running_processes)
        fi
    done
    
    echo ""
    echo "All ${#PIDS[@]} fetch processes started"
}

# Function to count running processes
count_running_processes() {
    local running=0
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            ((running++))
        fi
    done
    echo $running
}

# Function to wait for some processes to complete
wait_for_some_completion() {
    local initial_running=$(count_running_processes)
    local current_running=$initial_running
    
    # Wait until at least half complete
    local target=$((initial_running / 2))
    if [ $target -lt 1 ]; then
        target=1
    fi
    
    while [ $current_running -gt $target ]; do
        sleep 1
        current_running=$(count_running_processes)
    done
}

# Function to monitor parallel processes
monitor_progress() {
    echo "Monitoring parallel execution..."
    echo "=================================="
    
    local total_processes=${#PIDS[@]}
    local completed=0
    local failed=0
    
    while [ $completed -lt $total_processes ]; do
        completed=0
        failed=0
        
        echo -ne "\rProgress: "
        
        for i in "${!PIDS[@]}"; do
            local pid=${PIDS[$i]}
            local pokemon=${POKEMON_NAMES[$i]}
            local pokemon_lower=$(echo "$pokemon" | tr '[:upper:]' '[:lower:]')
            local status_file="$OUTPUT_DIR/.${pokemon_lower}.status"
            
            if [ -f "$status_file" ]; then
                local status=$(cat "$status_file")
                case "$status" in
                    SUCCESS:*)
                        echo -ne ""
                        ((completed++))
                        ;;
                    FAILED:*)
                        echo -ne ""
                        ((completed++))
                        ((failed++))
                        ;;
                    STARTED)
                        echo -ne "⏳"
                        ;;
                esac
            elif kill -0 "$pid" 2>/dev/null; then
                echo -ne ""
            else
                echo -ne ""
                ((completed++))
            fi
        done
        
        echo -ne " ($completed/$total_processes)"
        
        if [ $completed -lt $total_processes ]; then
            sleep 1
        fi
    done
    
    echo ""
    echo ""
}

# Function to wait for all processes and collect results
wait_for_completion() {
    echo "Waiting for all parallel processes to complete..."
    
    # Start progress monitoring in background
    monitor_progress &
    local monitor_pid=$!
    
    # Wait for all background processes
    for pid in "${PIDS[@]}"; do
        wait "$pid"
        local exit_code=$?
        RESULTS+=($exit_code)
    done
    
    # Stop progress monitoring
    kill "$monitor_pid" 2>/dev/null
    wait "$monitor_pid" 2>/dev/null
    
    echo "All parallel processes completed!"
    echo ""
}

# Function to analyze results
analyze_results() {
    echo "Parallel Execution Results:"
    echo "============================="
    
    local successful=0
    local failed=0
    
    for i in "${!POKEMON_NAMES[@]}"; do
        local pokemon=${POKEMON_NAMES[$i]}
        local pokemon_lower=$(echo "$pokemon" | tr '[:upper:]' '[:lower:]')
        local exit_code=${RESULTS[$i]}
        local output_file="$OUTPUT_DIR/${pokemon_lower}.json"
        local status_file="$OUTPUT_DIR/.${pokemon_lower}.status"
        
        if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
            local file_size=$(du -h "$output_file" 2>/dev/null | cut -f1)
            echo "$pokemon_lower.json ($file_size)"
            ((successful++))
        else
            echo "$pokemon_lower.json (failed)"
            if [ -f "$status_file" ]; then
                local status=$(cat "$status_file" | cut -d: -f2-)
                echo "   └─ Reason: $status"
            fi
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "   Successful: $successful/${#POKEMON_NAMES[@]}"
    echo "   Failed: $failed/${#POKEMON_NAMES[@]}"
    
    # Cleanup status files
    rm -f "$OUTPUT_DIR"/.*.status "$OUTPUT_DIR"/.*.tmp
    
    if [ $failed -gt 0 ]; then
        echo "   Check $ERROR_FILE for error details"
        return 1
    else
        echo "   All Pokemon data fetched successfully!"
        return 0
    fi
}

# Function to show performance comparison
show_performance_comparison() {
    local parallel_time=$1
    local estimated_sequential=$((${#POKEMON_LIST[@]} * 2)) # Assume 2s per request
    
    echo ""
    echo "⚡ Performance Comparison:"
    echo "========================="
    echo "Parallel execution: ${parallel_time}s"
    echo "Sequential estimate: ${estimated_sequential}s"
    
    if [ $parallel_time -lt $estimated_sequential ]; then
        local speedup=$(echo "scale=1; $estimated_sequential / $parallel_time" | bc 2>/dev/null || echo "~$((estimated_sequential / parallel_time))")
        echo "Speed improvement: ${speedup}x faster"
    fi
}

# Function to cleanup on script interruption
cleanup() {
    echo ""
    echo "Script interrupted! Cleaning up parallel processes..."
    
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
    done
    
    # Wait a moment for processes to terminate
    sleep 2
    
    # Force kill if necessary
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null
        fi
    done
    
    # Cleanup temporary files
    rm -f "$OUTPUT_DIR"/.*.status "$OUTPUT_DIR"/.*.tmp
    
    echo "Cleanup completed"
    exit 130
}

# Main execution function
main() {
    echo "⚡ Parallel Pokemon Data Fetching"
    echo "================================="
    echo "Pokemon list: ${POKEMON_LIST[*]}"
    echo "Output directory: $OUTPUT_DIR"
    echo "Parallel processing enabled"
    echo ""
    
    # Record start time
    local start_time=$(date +%s)
    
    # Initialize
    touch "$ERROR_FILE"
    setup_directory
    
    # Clear arrays
    PIDS=()
    POKEMON_NAMES=()
    RESULTS=()
    
    # Start parallel fetches
    start_parallel_fetches
    
    # Wait for completion and collect results
    wait_for_completion
    
    # Analyze results
    if analyze_results; then
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        
        show_performance_comparison $total_time
        
        echo ""
        echo "Parallel processing completed successfully in ${total_time}s!"
    else
        echo ""
        echo "Parallel processing completed with some failures"
        exit 1
    fi
}

# Set up signal handling
trap cleanup INT TERM

# Export function for background processes
export -f fetch_pokemon_parallel log_error

# Run main function
main "$@"