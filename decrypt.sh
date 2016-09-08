#! /bin/bash
# decrypt base64 encoded file and emits
decrypt() {
  local base64_encoded_ciphertext_file=$1
  local plaintext_file=$2
  local blob_dir=$(mktemp -d)
  cat $base64_encoded_ciphertext_file | base64 --decode > $blob_dir/blob
  aws kms decrypt --ciphertext-blob fileb://$blob_dir/blob --query Plaintext --output text | base64 --decode > $plaintext_file
}

# decrypt ciphers object.
#   first argument: payload file path
#   second argument: jq query to specify ciphers object
#   third argment: path to output
#
# example of ciphers_object(in yaml)
#   ---
#   cipher_name1: base64_encoded_cipher_text1
#   cipher_name2: base64_encoded_cipher_text2
decrypt_ciphers(){
  local payload=$1
  local ciphers_path=$2
  local destination=$3
  local ciphers_json=$(jq -r "$ciphers_path // {} | to_entries" < $payload)
  local num=$(jq -r "$ciphers_path // {} | to_entries | length" < $payload)
  if [ $num -gt 0 ]; then
    cipherblob_dir=$(mktemp -d)
    for i in $(seq 0 $(expr $num - 1)); do
      cipher_name=$(echo $ciphers_json | jq -r .[$i].key)
      echo $ciphers_json | jq -r .[$i].value > $cipherblob_dir/$cipher_name
      decrypt $cipherblob_dir/$cipher_name $destination/$cipher_name
      echo "\"$cipher_name\" successfully decrypted via kms.  Plaintext stored to \"$destination/$cipher_name\""
    done
  else
    echo "no ciphers given. skipped."
  fi
}

# decrypt cipher_files object.
#   first argument: payload file path
#   second argument: jq query to specify cipher_files object
#
# example of cipher_files_object(in yaml)
#   ---
#   cipher_name1: /path/to/cipher_file_for_1
#   cipher_name2: /path/to/cipher_file_for_2
decrypt_cipher_files(){
  local payload=$1
  local ciphers_path=$2
  local destination=$3
  local ciphers_json=$(jq -r "$ciphers_path // {} | to_entries" < $payload)
  local num=$(jq -r "$ciphers_path // {} | to_entries | length" < $payload)
  if [ $num -gt 0 ]; then
    cipherblob_dir=$(mktemp -d)
    for i in $(seq 0 $(expr $num - 1)); do
      cipher_name=$(echo $ciphers_json | jq -r .[$i].key)
      cipher_input_path=$(echo $ciphers_json | jq -r .[$i].value)
      decrypt $cipher_input_path $destination/$cipher_name
      echo "\"$cipher_input_path\" successfully decrypted via kms.  Plaintext stored to \"$destination/$cipher_name\""
    done
  else
    echo "no cipher_files given. skipped."
  fi
}
