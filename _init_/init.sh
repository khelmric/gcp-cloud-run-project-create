#!/bin/bash

###########################################################################################
# Init script to prepare the management environment for project onboarding with Cloud Run #
# Target environment: Google Cloud                                                        #
# Author:             Kristof Helmrich                                                    #
# Date:               2021-01-08                                                          #
###########################################################################################

# define colors
  COL_TITLE='\033[0;36m'
  COL_ERR='\033[0;31m'
  COL_WARN='\033[0;33m'
  COL_OK='\033[0;32m'
  COL_DEFAULT='\033[0m'

# print title
  echo -e "\n\n${COL_TITLE}Initialize GCP Cloud Run for Project onboarding${COL_DEFAULT}"

# check options

  while getopts ":ho:p:s:" opt; do
    case ${opt} in
      h)
        echo ""
        echo "Usage:"
        echo "$0 [-h] -o \"<ORG_ID>\" -p \"<PROJECT_ID>\" -s \"<SERVICE_ACCOUNT_ID>\""
        echo ""
        echo "Options:"
        echo " -h"
        echo "   Print help screen."
        echo " -o"
        echo "   Organization ID."
	echo " -p"
        echo "   Project ID."
	echo " -s"
        echo "   Service Account ID."
        ;;
      o)
        ORG_ID=${OPTARG}
        ;;
      p)
        PROJECT_ID=${OPTARG}
        ;;

      s)
        SERVICE_ACCOUNT_ID=${OPTARG}
        ;;
      \?)
        echo -e "[ ${COL_WARN}UNKNOWN${COL_DEFAULT} ] - Invalid option: -${OPTARG}; Please run $0 -h."
        exit 3
        ;;
      :)
        echo -e "[ ${COL_WARN}UNKNOWN${COL_DEFAULT} ] - ${OPTARG} requires an argument."
        exit 3
        ;;
    esac
  done

  if [[ -z ${ORG_ID} ]] ; then
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - No ORG_ID specified. Please run \"$0 -h\"."
    exit 1
  fi
  if [[ -z ${PROJECT_ID} ]] ; then
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - No PROJECT_ID specified. Please run \"$0 -h\"."
    exit 1
  fi
  if [[ -z ${SERVICE_ACCOUNT_ID} ]] ; then
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - No SERVICE_ACCOUNT_ID specified. Please run \"$0 -h\"."
    exit 1
  fi

# check if gcloud command is available 
  which gcloud > /dev/null
  if [[ $? == 0 ]] ; then
    echo -e "[ ${COL_OK}OK${COL_DEFAULT} ] - Google Cloud SDK is available."
  else
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - Google Cloud SDK is not available. Please install it on this node. (see https://cloud.google.com/sdk/docs/install)"
    exit 1
  fi


# check if the org is reachable
  ORG_DOMAIN=`gcloud organizations list --format="get(displayName)" --filter="name:organizations/${ORG_ID}"`
  if [[ ! -z ${ORG_DOMAIN} ]] ; then
    echo -e "[ ${COL_OK}OK${COL_DEFAULT} ] - Organization (ID:${ORG_ID}) is reachable."
  else
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - Organization (ID:${ORG_ID}) is not reachable. Please check if it exist or verify your IAM permissions."
    exit 1
  fi

# check if the project is reachable
  PROJECT_NUMBER=`gcloud projects list --format="get(projectNumber)" --filter="projectId:${PROJECT_ID}"`
  if [[ ! -z ${PROJECT_NUMBER} ]] ; then
    echo -e "[ ${COL_OK}OK${COL_DEFAULT} ] - Project (ID:${PROJECT_ID}) is reachable."
  else
    echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - Project (ID:${PROJECT_ID}) is not reachable. Please check if it exist or verify your IAM permissions."
    exit 1
  fi

# check service account, create if not exist
  until [[ ! -z ${SERVICE_ACCOUNT_EMAIL} ]] ; do
    SERVICE_ACCOUNT_EMAIL=`gcloud iam service-accounts list --format="get(email)" --filter="email=${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" --project ${PROJECT_ID}`
    if [[ ! -z ${SERVICE_ACCOUNT_EMAIL} ]] ; then
      echo -e "[ ${COL_OK}OK${COL_DEFAULT} ] - Service Account (ID:${SERVICE_ACCOUNT_ID}) exists."
    else
      echo -e "[ ${COL_WARN}WARNING${COL_DEFAULT} ] - Service Account (ID:${SERVICE_ACCOUNT_ID}) does not exist. Create..."
      gcloud iam service-accounts create "${SERVICE_ACCOUNT_ID}" \
        --description "Pipeline service account" \
        --display-name "${SERVICE_ACCOUNT_ID}" \
	--project "${PROJECT_ID}" > /dev/null
      if [[ $? != 0 ]] ; then
        echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - Failed to create Service Account. Please check your IAM permissions."
        exit 1
      fi
    fi
  done  

# check if cloud run service is enabled
  until [[ "${STATE}" == "ENABLED" ]] ; do
    STATE=`gcloud services list --format="get(state)" --filter="config.name:run.googleapis.com" --project ${PROJECT_ID}`
    if [[ "${STATE}" == "ENABLED" ]] ; then
      echo -e "[ ${COL_OK}OK${COL_DEFAULT} ] - Cloud Run service is enabled."
    else
      echo -e "[ ${COL_WARN}WARNING${COL_DEFAULT} ] - Cloud Run service is not enabled. Enabling..."
      gcloud services enable run.googleapis.com --project ${PROJECT_ID} > /dev/null
      if [[ $? != 0 ]] ; then
        echo -e "[ ${COL_ERR}ERROR${COL_DEFAULT} ] - Failed to enabling Cloud Run service. Please check your IAM permissions."
        exit 1
      fi
    fi
  done 

# create cloud run service
  #todo: define service account, build image
  gcloud run deploy cloud-run-name-here --region us-west1 --no-allow-unauthenticated --image https://github.com/khelmric/gcp-cloud-run-project-create.git:latest --platform managed --project create-project-with-cloud-run
