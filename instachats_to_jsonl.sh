#!/bin/bash

# Input and output file paths
input_file="/path/to/input.json"
output_file="/path/to/output.jsonl"

# Clear the output file if it exists
> "$output_file"

# Check if the input file exists
if [[ ! -f "$input_file" ]]; then
    echo "❌ Error: Input file does not exist: $input_file"
    exit 1
fi

echo "🔄 Extracting messages from JSON..."

# Define phrases to ignore
IGNORE_PHRASES=("You sent an attachment." "You sent a photo." "You sent a video." "You sent a voice message." "You sent a sticker." "You sent a file.")

# Extract messages using jq
jq -r '.messages[] | select(.content != null) | @json' "$input_file" | while read -r line; do
    sender=$(echo "$line" | jq -r '.sender_name')
    message=$(echo "$line" | jq -r '.content')

    # Convert encoding to UTF-8 (fixes garbled text)
    message=$(echo "$message" | iconv -c -f utf-8 -t utf-8)

    # Remove hidden control characters (non-printable)
    message=$(echo "$message" | tr -cd '[:print:]')

    # Remove common garbled characters
    message=$(echo "$message" | sed 's/�//g')

    # Remove URLs (social media links)
    message=$(echo "$message" | sed -E 's#https?://[^ ]+##g')

    # Trim spaces, tabs, and newlines
    message=$(echo "$message" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty, null, or whitespace-only messages
    if [[ -z "$message" || "$message" == "null" || "$message" =~ ^[[:space:]]*$ ]]; then
        continue
    fi

    # Skip attachment messages
    for phrase in "${IGNORE_PHRASES[@]}"; do
        if [[ "$message" == "$phrase" ]]; then
            continue 2  # Skip to the next message
        fi
    done

    # Escape double quotes for valid JSON output
    message=$(echo "$message" | sed 's/"/\\"/g')

    # Write to JSONL format
    echo "{\"instruction\": \"Respond to $sender\", \"input\": \"$message\", \"output\": \"\"}" >> "$output_file"
done

echo "✅ Conversion complete. Output saved to $output_file."

