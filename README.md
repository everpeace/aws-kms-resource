# aws-kms-resource
Concourse CI resource for decrypting your secrets by AWS Key Management Service

# Example pipeline

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
      aws_access_key_id: xxx
      aws_secret_access_key: yyyyyyyyyy
      aws_region: us-east-1
      ciphers:
        # values are base64 encoded cipher text
        credential_name1: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==
        credential_name2: AQECAHgZ3RW+tvS__base64_encoded_cipher_text__AVQGT+RGxmY3Q==

jobs:
  - name: decrypt_credentials
    plan:
      - get: credentials
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
```
