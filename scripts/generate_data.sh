#!/bin/bash

#
# Function Declarations
#
function download {
    if [ ! -f "$1" ]; then
        wget -O "$1" "$2"
    fi
}

function create_list {
    echo "creating list: ${1}"
    ogrinfo "${DB_DIR}" -sql "SELECT DISTINCT ${1} FROM ${2}" | grep "=" | sed 's/^.* = //g' > "${DATA_DIR}${1}.txt"
}

function generate_geojson {
    echo "generating geojson from: ${3}"
    while read item; do
        echo "    - ${1}: ${2}/${item}"
        ogr2ogr -f GeoJSON -where "${1} = '${item}'" "${GEOJSON_DIR}${2}/${item}.json" "${DB_DIR}${3}.shp"
    done <"${DATA_DIR}${1}.txt"
}

function get_data {
    #
    # Config Section
    #
    SCALE="$1"  # can be: 10m, 50m, or 110m
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    BASE_DIR="${DIR}/../"
    DATA_DIR="${BASE_DIR}data/${SCALE}/"
    DB_DIR="${DATA_DIR}db/"
    DOWNLOADS_DIR="${DATA_DIR}downloads/"
    GEOJSON_DIR="${DATA_DIR}/geojson/"
    DL_PREFIX="http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/${SCALE}/cultural/"
    COUNTRIES="ne_${SCALE}_admin_0_countries"
    COUNTRIES_FILE="${COUNTRIES}.zip"
    COUNTRIES_PATH="${DOWNLOADS_DIR}${COUNTRIES_FILE}"
    COUNTRIES_URL="${DL_PREFIX}${COUNTRIES_FILE}"
    SUBDIVISIONS="ne_${SCALE}_admin_1_states_provinces"
    SUBDIVISIONS_FILE="${SUBDIVISIONS}.zip"
    SUBDIVISIONS_PATH="${DOWNLOADS_DIR}${SUBDIVISIONS_FILE}"
    SUBDIVISIONS_URL="${DL_PREFIX}${SUBDIVISIONS_FILE}"
    # subdivision hack: 50m has "_shp" appended to table names
    SUBDIVISIONS="${SUBDIVISIONS}${2}"

    #
    # make directories
    #
    mkdir -p "$DB_DIR"
    mkdir -p "$DOWNLOADS_DIR"
    mkdir -p "${GEOJSON_DIR}continents"
    mkdir -p "${GEOJSON_DIR}countries"
    mkdir -p "${GEOJSON_DIR}regions_un"
    mkdir -p "${GEOJSON_DIR}regions_wb"
    mkdir -p "${GEOJSON_DIR}subregions"

    #
    # downloads
    #
    download "${COUNTRIES_PATH}" "${COUNTRIES_URL}"
    download "${SUBDIVISIONS_PATH}" "${SUBDIVISIONS_URL}"

    #
    # extract zip files
    #
    echo "extracting files:"
    tar -xvf "${COUNTRIES_PATH}" --directory "${DB_DIR}"
    tar -xvf "${SUBDIVISIONS_PATH}" --directory "${DB_DIR}"

    #
    # create some lists
    #
    create_list "CONTINENT" "${COUNTRIES}"
    create_list "REGION_UN" "${COUNTRIES}"
    create_list "REGION_WB" "${COUNTRIES}"
    create_list "SUBREGION" "${COUNTRIES}"
    create_list "ISO_A2" "${SUBDIVISIONS}"

    #
    # clear geojson folder
    #
    echo "clearing geojson folder."
    find "${GEOJSON_DIR}" -name "*.json" -type f -delete

    #
    # generate world geojson file
    #
    echo "generating world geojson."
    ogr2ogr -f GeoJSON "${GEOJSON_DIR}world.json" "${DB_DIR}${COUNTRIES}.shp"

    #
    # generate geojson files
    #
    generate_geojson "CONTINENT" "continents" "${COUNTRIES}"
    generate_geojson "REGION_UN" "regions_un" "${COUNTRIES}"
    generate_geojson "REGION_WB" "regions_wb" "${COUNTRIES}"
    generate_geojson "SUBREGION" "subregions" "${COUNTRIES}"
    generate_geojson "ISO_A2" "countries" "${SUBDIVISIONS}"

    # we're finished
    echo "Done generating geojson files!"
}

get_data "10m" ""
get_data "50m" "_shp"
get_data "110m" ""



