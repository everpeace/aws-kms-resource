# AWS Key Management Service Resource
Concourse CI resource for decrypting your secrets used in concourse tasks by AWS Key Management Service.

Please note that this resource does NOT aim to make ALL credentials in pipeline definition be secured.  This cannot make credentials which is set in resource definitions (e.g. s3, git, etc.) be secure.

However, this resource is useful to make credentials used in tasks be secure.  For example, username and password for production DB access, these would be passed to deployment job usually.  These credentials are really sensitive.  

As you might know, 'fly get-pipeline' command can get all pipeline definition which includes credentials.  Thus, this resource can save those credentials from malicious users.

## Deploying to Concourse

You can use the docker image by defining the [resource type](http://concourse.ci/configuring-resource-types.html) in your pipeline YAML.

For example:

```yaml

resource_types:
- name: aws-kms
  type: docker-image
  source:
    repository: everpeace/aws-kms-resource
```

## Source Configuration
__CAUTION: I recommend you not to embed these aws api credentials in pipeline definitions.  Beacause, if aws api credentials and cipher texts given, these information is not secure at all.  Attaching InstanceProfiles to concourse worker are highly recommended.__
* `aws_access_key_id`: *Optional.*  If not set, instance profiles are used when concourse worker runs on AWS.
* `aws_secret_access_key`: *Optional.* If not set, instance profiles are used when concourse worker runs on AWS.
* `aws_region`: *Optional.* Default value is `us-east-1`.
* `ciphers`: *Optional.* Object which contains cipher texts you want to decrypt.  Key of the object should be credential name.  Value of the key should be base64 encoded cipher text.  You can get this encoded string by `aws kms encrypt --key-id xxxxx --plaintext some_credential_plaintext --output text --query CiphertextBlob`

  Example:
  ```
  ciphers:
    credential_name1: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
    credential_name2: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
  ```

## Behavior
### `check`
Now, check returns new version based on date *in every minute*. We plan to support the latest encrypted date to detect 're-encryption' of the specified secrets.

### `in`: decrypt your ciphers and emits plaintexts
Decrypt passed each cipher text and emit plaintext to the file whose name is given credential name.

If you configured like this:
```
resources:
  - name: credentials
    type: aws-kms
    source:
      ciphers:
        credential_name1: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
        credential_name2: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==

jobs:
  - name: decrypt_credentials
    plan:
      - get: credentials
```

you can find plaintext in files of `credentials/credential_name1` and `credentials/credential_name2`

#### Parameters
* `ciphers`: *Optional.* Object which contains cipher texts you want to decrypt (the same format with Source Configuration above).

### `out`
Do nothing.

## Example Pipeline
This is simple pipeline example.
```
resource_types:
  - name: aws-kms
    type: docker-image
    source:
      repository: everpeace/aws-kms-resource

resources:
  - name: credentials
    type: aws-kms
    source:
      # embedding aws api is NOT recommended.
      # Instead, you can attach instance profiles to concourse workers.
      # aws_access_key_id: xxx
      # aws_secret_access_key: yyyyyyyyyy
      aws_region: us-east-1
      ciphers:
        # values are base64 encoded cipher text
        credential_name1: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
        credential_name2: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==

jobs:
  - name: decrypt_credentials
    plan:
      - get: credentials
        params:
          ciphers:
            credential_name3: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
      - task: cat_credentials
        config:
          platform: linux
          image_resource:
            type: docker-image
            source:
              repository: getourneau/alpine-bash-git
          inputs:
            - name: credentials
          run:
            path: /bin/bash
            args:
              - -exc
              - |
                cat credentials/credential_name1
                cat credentials/credential_name2
                cat credentials/credential_name3
```

## Can we decrypt files in other resources??
Yes!  [aws-kms-resource](https://hub.docker.com/r/everpeace/aws-kms-resource/) docker image ships `decrypt` utility.  So you can easily decrypt your cipher text via kms in concourse tasks!
To use `decrypt` utility, you need to source `/opt/resource/decrypt.sh` in container.  And then you can use `decrypt` function.

`decrypt` function takes two arguments
* first argument should be a path which contains base64 encoded cipher text.
* second argument should be output path which will contain plain text of given cipher text.

Here is an example.
```
resources:
  - name: repo
    type: git
    source:
      uri: git@github.com:some_org/public_repo

jobs:
  - name: decrypt_file_in_repo
    plan:
      - get: repo
      - task: decrypt_credential
        config:
          platform: linux
          image_resource:
            type: docker-image
            source:
              repository: everpeace/aws-kms-resource
          inputs:
            - name: repo
          outputs:
            - name: outputs
          params:
            # embedding aws api is NOT recommended.
            # Instead, you can attach instance profiles to concourse workers.
            # AWS_ACCESS_KEY_ID: xxx
            # AWS_SECRET_ACCESS_KEY: yyyyyy
            AWS_DEFAULT_REGION: us-east-1
          run:
            path: /bin/bash
            args:
            - -ec
            - |
              source /opt/resource/decrypt.sh
              decrypt repo/file_contains_base_64_encoded_cipher_text outputs/plain_text
              cat /outputs/plain_text
```
## Tests
todo.
