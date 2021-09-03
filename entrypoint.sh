#!/bin/bash
set -e

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	if [ -n "${INPUT_LAMBDA_LAYER_VERSION}" ]
	then
		if [ $(wc -c <dependencies.zip) -gt 52428800 ] && [ -n "${INPUT_S3_BUCKET_NAME}" ]
	  then
			echo "Uploading dependencies to S3..."
			aws s3 cp dependencies.zip s3://"${INPUT_S3_BUCKET_NAME}"/"${INPUT_LAMBDA_LAYER_ARN}"_dependencies.zip
			echo "Publishing dependencies from S3 as a layer..."
			local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --content S3Bucket="${INPUT_S3_BUCKET_NAME}",S3Key="${INPUT_LAMBDA_LAYER_ARN}"_dependencies.zip)
		else
			echo "Publishing dependencies as a layer..."
			local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
		fi
		LAYER_VERSION=$(jq '.Version' <<< "$result")
	else
		LAYER_VERSION="${INPUT_LAMBDA_LAYER_VERSION}"
	fi
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code itself..."
	zip -r code.zip . -x \*.git\*
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

publish_version(){
	echo "Publishing a new version..."
	aws publish-version --function-name "${INPUT_LAMBDA_FUNCTION_NAME}"
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	update_function_layers
	publish_version
}

deploy_lambda_function
echo "Done."
