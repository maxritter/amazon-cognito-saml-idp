#! /bin/bash

set -e
set -u
set -o pipefail

SSM_ROOT="<YOUR_SSM_ROOT>"

# Running CDK Project

# Starting point is the root directory. Need to chdir
cd ./cdk-infra

# Synth
echo "===> Running CDK synth..."
cdk synth

# Bootstraping
echo "===> Bootstraping account"
cdk bootstrap

# # Deploy
echo "===> Deploying CDK project..."
cdk deploy --require-approval never

# # get cloud front distribution url
echo "===> Fetching cloudfront distribution url /${SSM_ROOT}/cloudfront/distributionUrl..."
CF_DISTRIBUTION_URL=`aws ssm get-parameters --with-decryption --names "/${SSM_ROOT}/cloudfront/distributionUrl"  --query 'Parameters[*].Value' --output text`
echo "===> Fetched cloudfront distribution url ${CF_DISTRIBUTION_URL}..."

# Switching the the ui src directory
echo "===> Switching directroy to main"
cd ..
pwd

echo "===> Original Config:"
head -n 15 ./src/config.js

echo "===> Updating UI Project Config:"
node ./src/scripts/setup-ui.js

echo "===> Building UI App..."
yarn run build

echo "===> Building UI Project is done."

# get the deployment bucket name
echo "===> Fetching bucket /${SSM_ROOT}/bucket/uiDeploymentBucketName..."
DEPLOYMENT_BUCKET=`aws ssm get-parameters --with-decryption --names "/${SSM_ROOT}/bucket/uiDeploymentBucketName"  --query 'Parameters[*].Value' --output text`

echo "===> Copying build archifacts to S3 bucket: ${DEPLOYMENT_BUCKET}..."
aws s3 sync ./build s3://${DEPLOYMENT_BUCKET}/build

# # get cloud front distribution id
CF_DISTRIBUTION_ID=`aws ssm get-parameters --with-decryption --names "/${SSM_ROOT}/cloudfront/distributionId"  --query 'Parameters[*].Value' --output text`
echo "===> Invalidating cloud formation distribution: ${CF_DISTRIBUTION_ID}"
aws cloudfront create-invalidation \
    --distribution-id ${CF_DISTRIBUTION_ID} \
    --paths "/*"

echo "===> Deployment is done."
