#!/bin/bash

# Prompt for IBM Cloud API key
read -s -p "Enter your IBM Cloud API key: " IBM_CLOUD_API_KEY
echo

# Log in to IBM Cloud CLI
# ibmcloud login --apikey "$IBM_CLOUD_API_KEY"
# ibmcloud login --apikey ""

# Prompt for IBM Cloud region selection
echo "Select IBM Cloud region:"
select REGION in us-south us-east eu-gb eu-de
do
    case $REGION in
        us-south|us-east|eu-gb|eu-de)
            echo "Selected IBM Cloud region: $REGION"
            break
            ;;
        *)
            echo "Invalid selection. Please try again."
            ;;
    esac
done

# Set the target region
ibmcloud target -r $REGION

# List Key Protect service instances
echo "Listing Key Protect service instances..."
SERVICE_INSTANCES=$(ibmcloud resource service-instances --service-name "kms" --output JSON)

# Prompt for Key Protect instance selection
echo "Select Key Protect instance:"
echo "$SERVICE_INSTANCES" | jq -r '.[] | .index, .name, .crn'
read -p "Enter the number of the Key Protect instance you want to select: " INSTANCE_INDEX

# Get the instance GUID and CRN of the selected instance
INSTANCE_GUID=$(echo "$SERVICE_INSTANCES" | jq -r --argjson INSTANCE_INDEX "$INSTANCE_INDEX" '.[$INSTANCE_INDEX - 1] | .guid')

if [[ -n $INSTANCE_GUID ]]; then
  echo "Selected Key Protect instance: $INSTANCE_GUID"

  # Set the Key Protect instance as the active instance
  ibmcloud kp region-set $REGION
  export KP_INSTANCE_ID="$INSTANCE_GUID"

    while true; do
        echo "Please choose one of the following options:"
        echo "1) List Keys"
        echo "2) Import New Key"
        echo "3) Rotate Key"
        echo "4) Key versions"
        echo "5) Exit"

        read -p "Enter your choice (1-4): " choice

        case $choice in
            1)
                # List keys in the selected Key Protect instance
                echo "Listing keys in the selected Key Protect instance..."
                ibmcloud kp keys
                ;;
            2)
                echo "Cleanup previous key data"
                cleanup.sh

                # Create import token and save response to createImportTokenResponse.json
                echo "Creating import token..."
                ibmcloud kp import-token create --output json > createImportTokenResponse.json

                # Retrieve import token and save response to getImportTokenResponse.json
                echo "Retrieving import token..."
                IMPORT_TOKEN=$(cat createImportTokenResponse.json | jq -r '.token')
                ibmcloud kp import-token show --output json > getImportTokenResponse.json

                # Get the value of 'payload' attribute from getImportTokenResponse.json and base64 encode it
                PUBLIC_KEY=$(cat getImportTokenResponse.json | jq -r '.payload')

                # Write the base64 encoded payload to PublicKey.pem file
                echo "$PUBLIC_KEY" > PublicKey.pem

                echo "Import token payload has been saved to PublicKey.pem file."

                # Prompt user to provide Key Material
                read -p "Enter the Key Material to be encrypted: " KEY_MATERIAL

                # Generate the 256-bit key
                # echo "Generate the 256-bit key"
                # openssl rand 32 > PlainTextKey.bin
                # KEY_MATERIAL=$(base64 -i PlainTextKey.bin)
                echo "$KEY_MATERIAL" > EncodePlainTextKey.txt

                # Extract the value of 'nonce' attribute from getImportTokenResponse.json
                NONCE=$(cat getImportTokenResponse.json | jq -r '.nonce')

                # Encrypt the nonce using Key Material
                echo "Encrypting the nonce using Key Material..."
                ENCRYPTED_NONCE_RESPONSE=$(ibmcloud kp import-token nonce-encrypt --nonce "$NONCE" --key "$KEY_MATERIAL" --output json)

                # Save the encrypted values to EncryptedResponse.json
                echo "$ENCRYPTED_NONCE_RESPONSE" > EncryptedNonceResponse.json

                echo "Encryption Nonce output has been saved to EncryptedNonceResponse.json file."

                jq '.' EncryptedNonceResponse.json

                # Encrypt the nonce using Key Material
                echo "Encrypting the key using Key Material..."
                ENCRYPTED_KEY_RESPONSE=$(ibmcloud kp import-token key-encrypt --pubkey "$PUBLIC_KEY" --key "$KEY_MATERIAL" --output json)

                # Save the encrypted values to EncryptedResponse.json
                echo "$ENCRYPTED_KEY_RESPONSE" > EncryptedKeyResponse.json

                echo "Encryption Nonce output has been saved to EncryptedKeyResponse.json file."

                jq '.' EncryptedKeyResponse.json

                ENCRYPTED_KEY=$(jq -r '.encryptedKey' EncryptedKeyResponse.json)
                ENCRYPTED_NONCE=$(jq -r '.encryptedNonce' EncryptedNonceResponse.json)
                IV=$(jq -r '.iv' EncryptedNonceResponse.json)

                # Prompt the user for key name
                echo -n "Enter key name: "
                read KEY_NAME

                # Prompt the user for key name
                echo -n "Enter key alias: "
                read KEY_ALIAS

                echo "Importing encrypted key material..." 
                IMPORT_ENCRYPTED_ROOT_KEY_RESPONSE=$(ibmcloud kp key create "$KEY_NAME" -a "$KEY_ALIAS" -k "$ENCRYPTED_KEY" -n "$ENCRYPTED_NONCE" -v "$IV" --output json)

                # Save the create key response to ImportRootKeyResponse.json
                echo "$IMPORT_ENCRYPTED_ROOT_KEY_RESPONSE" > ImportRootKeyResponse.json

                jq '.' ImportRootKeyResponse.json

                ;;
            3)
                echo "Cleanup previous key data"
                cleanup.sh

                # Create import token and save response to createImportTokenResponse.json
                echo "Creating import token..."
                ibmcloud kp import-token create --output json > createImportTokenResponse.json

                # Retrieve import token and save response to getImportTokenResponse.json
                echo "Retrieving import token..."
                IMPORT_TOKEN=$(cat createImportTokenResponse.json | jq -r '.token')
                ibmcloud kp import-token show --output json > getImportTokenResponse.json

                # Get the value of 'payload' attribute from getImportTokenResponse.json and base64 encode it
                PUBLIC_KEY=$(cat getImportTokenResponse.json | jq -r '.payload')

                # Write the base64 encoded payload to PublicKey.pem file
                echo "$PUBLIC_KEY" > PublicKey.pem

                echo "Import token payload has been saved to PublicKey.pem file."

                # Prompt user to provide Key Material
                # read -p "Enter the Key Material to be encrypted: " KEY_MATERIAL

                # Generate the 256-bit key 
                echo "Generate the 256-bit key using openssl"
                openssl rand 32 > PlainTextKey.bin
                KEY_MATERIAL=$(base64 -i PlainTextKey.bin)
                echo "$KEY_MATERIAL" > EncodePlainTextKey.txt

                # Extract the value of 'nonce' attribute from getImportTokenResponse.json
                NONCE=$(cat getImportTokenResponse.json | jq -r '.nonce')

                # Encrypt the nonce using Key Material
                echo "Encrypting the nonce using Key Material..."
                ENCRYPTED_NONCE_RESPONSE=$(ibmcloud kp import-token nonce-encrypt --nonce "$NONCE" --key "$KEY_MATERIAL" --output json)

                # Save the encrypted values to EncryptedResponse.json
                echo "$ENCRYPTED_NONCE_RESPONSE" > EncryptedNonceResponse.json

                echo "Encryption Nonce output has been saved to EncryptedNonceResponse.json file."

                jq '.' EncryptedNonceResponse.json

                # Encrypt the nonce using Key Material
                echo "Encrypting the key using Key Material..."
                ENCRYPTED_KEY_RESPONSE=$(ibmcloud kp import-token key-encrypt --pubkey "$PUBLIC_KEY" --key "$KEY_MATERIAL" --output json)

                # Save the encrypted values to EncryptedResponse.json
                echo "$ENCRYPTED_KEY_RESPONSE" > EncryptedKeyResponse.json

                echo "Encryption Nonce output has been saved to EncryptedKeyResponse.json file."

                jq '.' EncryptedKeyResponse.json

                ENCRYPTED_KEY=$(jq -r '.encryptedKey' EncryptedKeyResponse.json)
                ENCRYPTED_NONCE=$(jq -r '.encryptedNonce' EncryptedNonceResponse.json)
                IV=$(jq -r '.iv' EncryptedNonceResponse.json)

                # Prompt the user for key name
                echo -n "Enter key alias of the to rotate: "
                read KEY_ALIAS

                echo "Rotate key material for imported key" 
                IMPORT_ENCRYPTED_ROOT_KEY_RESPONSE=$(ibmcloud kp key rotate "$KEY_ALIAS" -k "$ENCRYPTED_KEY" -n "$ENCRYPTED_NONCE" -v "$IV" --output json)

                # Save the create key response to ImportRootKeyResponse.json
                echo "$IMPORT_ENCRYPTED_ROOT_KEY_RESPONSE" > ImportRootKeyResponse.json

                cat ImportRootKeyResponse.json
                
                ;;
            4)
                # Prompt the user for key alias or id
                echo -n "To show versions, enter key alias or key id: "
                read KEY_ALIAS_OR_ID

                ibmcloud kp key versions "$KEY_ALIAS_OR_ID"

                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter a number from 1 to 4."
                ;;
        esac

        echo # Print an empty line for better readability
    done
  
  # Log out from IBM Cloud CLI
  ibmcloud logout
else
  echo "Invalid selection. Exiting..."
  exit 1
fi
