#!/bin/bash

# Generate the 256-bit key
key=$(openssl rand -hex 32)

# Encode the key with Base64
base64_key=$(echo -n "$key" | xxd -r -p | base64)

# Specify the output file
output_file="encoded_key.txt"

# Check if the output file already exists
if [ -f "$output_file" ]; then
    read -p "The file $output_file already exists. Do you want to overwrite it? (y/n) " overwrite

    if [[ $overwrite == [Yy] ]]; then
        echo "# Generated 256-bit key: $key" > "$output_file"
        echo "$base64_key" >> "$output_file"
        echo "Encoded key has been overwritten in $output_file."
    else
        # Generate a new filename
        timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="encoded_key_$timestamp.txt"
        echo "# Generated 256-bit key: $key" > "$output_file"
        echo "$base64_key" >> "$output_file"
        echo "Encoded key has been written to a new file: $output_file."
    fi
else
    echo "# Generated 256-bit key: $key" > "$output_file"
    echo "$base64_key" >> "$output_file"
    echo "Encoded key has been written to $output_file."
fi

echo "Generated 256-bit key: $key"

