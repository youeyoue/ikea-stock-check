#!/bin/bash
#
# Requires `curl' for API calls and `jq' for json parsing
# Queries are piped to `tee' into JSON files for debugging
#
# Usage:
# 	query.bash [logfile]
#
# 		logfile    Optional file for appending output
#
# Output: Timestamp and a semicolon separated line of tab separated entries
#

DATE=$(date +"%Y-%m-%d-%H:%M")
FILE="$1"

IDS=(
	[10354208]="BYGGLEK - LEGO® box with lid, white 13 3/4x10x4 1/2"
	[50372187]="BYGGLEK - LEGO® box with lid, white 10x6 7/8x4 1/2"
	[70372186]="BYGGLEK - LEGO® box with lid, set of 3, white"
)

STORE_CITY="Jacksonville"

## Get Store ID
STORES=$(curl 'https://ww8.ikea.com/ext/iplugins/v2/en_US/data/localstorefinder/data.json' \
  -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="90", "Google Chrome";v="90"' \
  -H 'Referer: https://www.ikea.com/' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36' \
  --silent --compressed | tee "stores.json")

STORE_ID=$(jq --raw-output '.[] | select(.storeCity | contains("'"${STORE_CITY}"'")) | .storeNumber' <<< "${STORES}")

#echo "CITY: ${STORE_CITY}, INDEX: ${STORE_ID}"

HEAD=$(echo -en "STOCK\tCOUNT\tSKU\tNAME")
OUT="${DATE};${HEAD}"

# Check stock for each item
for item in "${!IDS[@]}"; do
	data=$(curl "https://iows.ikea.com/retail/iows/us/en/stores/${STORE_ID}/availability/ART/${item}" \
	  -H 'sec-ch-ua: " Not;A Brand";v="99", "Google Chrome";v="91", "Chromium";v="91"' \
	  -H 'accept: application/vnd.ikea.iows+json;version=1.0' \
	  -H 'consumer: MAMMUT' \
	  -H 'Referer: ' \
	  -H 'contract: 37249' \
	  -H 'sec-ch-ua-mobile: ?0' \
	  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36' \
	  --silent --compressed | tee "${item}.json")

	name="${IDS[${item}]}"
	quantity=$(jq --raw-output '.StockAvailability.RetailItemAvailability.AvailableStock."$"' <<< "${data}")
	stock=$(jq --raw-output '.StockAvailability.RetailItemAvailability.InStockProbabilityCode."$"' <<< "${data}")

	OUT="${OUT}"$(echo -en ";${stock}\t${quantity}\t${item}\t${name}")
done

if [ -n "${FILE}" ]; then
	echo "${OUT}" >> "${FILE}"
else
	echo "${OUT}"
fi
