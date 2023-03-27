#!/usr/bin/env bats 

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/../images/base/scan-common.bash"

setup () {
clean_simple_json=$(cat <<"EOF"
{
    "findings": [
        {
            "title": ""
        }
    ]
}
EOF
)

clean_complex_json=$(cat <<"EOF"
{
    "findings": [
        {
            "description": {
                "infoText": ""
            }
        }
    ]
}
EOF
)

broken_json=$(cat <<"EOF"
{
    "findings": [
        {
            title: ""
        }
    ]
}
EOF
)

empty_json=""

empty_template=$(get_template)
}

@test "add_json_field() with correct input should return 0" {
    add_json_field title "test" "$clean_simple_json"
}

@test "add_json_field() with extra level and correct input should return 0" {
    add_json_field infoText "test" "$clean_complex_json" description
}

@test "add_json_field() with broken input should fail and return 1" {
    run -1 add_json_field title "test" "$broken_json"
}

@test "add_json_field() should fail and return 127 with empty input" {
    run -127 json=$(add_json_field title "test" "$empty_json")
}

@test "add_json_field() should return valid json for correct input" {
    json=$(add_json_field infoText "test" "$clean_complex_json" description)
    [ "$(jq -r '.findings[].description.infoText' <<< $json)" = "test" ]
}

@test "add_json_field() should return 127 for broken inputs" {
    run -127 json=$(add_json_field infoText "test" "$broken_json" description)
    jq <<< "$json"
    [ -z "$(jq -r '.findings[].description.infoText' <<< $json)" ]
}

@test "add_json_field() should return 0 and correctly set a given value for a each possible key" {
    json=$(get_template)
    json=$(add_json_field date "test_date" "$json")
    json=$(add_json_field title "test_title" "$json")
    json=$(add_json_field severity "test_severity" "$json")
    json=$(add_json_field infoText "test_infoText" "$json" description)
    json=$(add_json_field image "test_image" "$json" description)
    json=$(add_json_field cluster "test_cluster" "$json" description)
    json=$(add_json_field namespace "test_namespace" "$json" description)
    json=$(add_json_field mitigation "test_mitigation" "$json")
    json=$(add_json_field impact "test_impact" "$json")
    json=$(add_json_field references "test_references" "$json")

    [ "$(jq -r '.findings[].date' <<< $json)" = "test_date" ]
    [ "$(jq -r '.findings[].title' <<< $json)" = "test_title" ]
    [ "$(jq -r '.findings[].severity' <<< $json)" = "test_severity" ]
    [ "$(jq -r '.findings[].description.infoText' <<< $json)" = "test_infoText" ]
    [ "$(jq -r '.findings[].description.image' <<< $json)" = "test_image" ]
    [ "$(jq -r '.findings[].description.cluster' <<< $json)" = "test_cluster" ]
    [ "$(jq -r '.findings[].description.namespace' <<< $json)" = "test_namespace" ]
    [ "$(jq -r '.findings[].mitigation' <<< $json)" = "test_mitigation" ]
    [ "$(jq -r '.findings[].impact' <<< $json)" = "test_impact" ]
    [ "$(jq -r '.findings[].references' <<< $json)" = "test_references" ]
}

@test "add_json_field() should return 1 when a non-existing field is targeted" {
    run -1 add_json_field non_existing_field "test" "$(<tmp/clean_simple.json)"
}

@test "add_json_field() should return 1 when called with less than 3 or more than 4 parameters" {
    run -1 add_json_field 1 2
    run -1 add_json_field 1 2 3 4 5
}

@test "get_template() should return valid json" {
    jq <<<$(get_template)
}