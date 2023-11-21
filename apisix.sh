#!/usr/bin/bash

set -e

APISIX_ADMIN_URL="http://127.0.0.1:9180/apisix/admin"
APISIX_URL="http://127.0.0.1:9080"
URL="http://127.0.0.1:4504"
ADMIN_API_KEY="edd1c9f034335f136f87ad84b625c8f1"
TRIAL="trial"
PREMIUM="premium"

admin_curl() {
  path=$1
  method=$2
  body=$3

  curl -vv -H "X-API-KEY: $ADMIN_API_KEY" "$APISIX_ADMIN_URL/$path" -X "$method" -d "$body"
}

api_curl() {
  api_key=$1
  path=$2
  method=$3
  body=$4

  curl -vv -H "Accept-Language: en" \
  -H "Accept: aplication/json" \
  -H "Content-Type: application/json" \
  -H "Host: api.freepik.com" \
  -H "X-Freepik-API-Key: $api_key" \
  "$APISIX_URL/$path" -X "$method" -d "$body"
}

admin_curl_get() {
  path=$1

  admin_curl "$path" "GET"
}

admin_curl_put() {
  path=$1
  body=$2

  admin_curl "$path" "PUT" "$body"
}

api_curl_get() {
  api_key=$1
  path=$2

  api_curl "$api_key" "$path" "GET"
}

create_upstream() {
  admin_curl_put "upstreams/pro" '{
    "name": "Freepik",
    "nodes": {
      "host.docker.internal:4504": 1
    }
  }'
}

create_service() {
  admin_curl_put "services/pro" '{
    "name": "Freepik PRO",
    "plugins": {
      "key-auth": {
        "header": "X-Freepik-API-Key"
      },
      "prometheus": {
        "prefer_name": true
      },
      "proxy-rewrite": {
        "regex_uri": [
          "(.*+)",
          "/b2b$1"
        ]
      }
    },
    "upstream_id": "pro"
  }'
}

create_routes() {
  echo "Creating routes"

  admin_curl_put "routes/default" '{
    "name": "All routes",
    "uri": "/v1/*",
    "methods": ["GET"],
    "service_id": "pro"
  }'

  admin_curl_put "routes/resources_download" '{
    "name": "Resource download",
    "uri": "/v1/resources/*/download",
    "methods": ["GET"],
    "service_id": "pro"
  }'

  admin_curl_put "routes/legacy_download" '{
    "name": "Legacy download",
    "uri": "/v1/download",
    "methods": ["GET"],
    "service_id": "pro"
  }'

  admin_curl_put "routes/resources_download_formats" '{
    "name": "Resource formats download",
    "uri": "/v1/resources/*/download/*",
    "methods": ["GET"],
    "service_id": "pro"
  }'

  admin_curl_put "routes/icons_download" '{
    "name": "Icons download",
    "uri": "/v1/icons/*/download",
    "methods": ["GET"],
    "service_id": "pro"
  }'
}

create_consumer_group() {
  admin_curl_put "consumer_groups/$TRIAL" '
  {
    "plugins": {
      "response-rewrite": {
        "headers": {
          "set": {
            "x-product-name": "'$TRIAL'",
            "x-access-premium-resources": "0",
            "x-quota-limit": "3",
            "x-quota-timeunit": "",
            "x-quota-interval": "month"
          },
          "vars": [
            ["status", "==", 200]
          ],
          "group": "'$TRIAL'"
        }
      },
      "limit-count": {
        "count": 3,
        "time_window": 300,
        "rejected_code": 429,
        "rejected_msg": "Too many request",
        "show_limit_quota_header": false
      }
    }
  }
  '

  admin_curl_put "consumer_groups/$PREMIUM" '
  {
    "plugins": {
      "response-rewrite": {
        "headers": {
          "set": {
            "x-product-name": "'$PREMIUM'",
            "x-access-premium-resources": "0",
            "x-quota-limit": "10",
            "x-quota-timeunit": "",
            "x-quota-interval": "month"
          }
        },
        "vars": [
          ["status", "==", 200]
        ],
        "group": "'$PREMIUM'"
      },
      "limit-count": {
        "count": 5,
        "time_window": 300,
        "rejected_code": 429,
        "rejected_msg": "Too many request",
        "show_limit_quota_header": false
      }
    }
  }
  '
}

create_consumer_trial() {
  admin_curl_put "consumers" '
  {
    "username": "user1",
    "plugins": {
      "key-auth": {
        "key": "1234"
      }
    },
    "group_id": "'$TRIAL'"
  }
  '

  admin_curl_put "consumers" '
  {
    "username": "user2",
    "plugins": {
      "key-auth": {
        "key": "4321"
      }
    },
    "group_id": "'$TRIAL'"
  }
  '

  admin_curl_put "consumers" '
    {
      "username": "no_limit_free",
      "plugins": {
        "key-auth": {
          "key": "7777"
        },
        "limit-count": {
          "count": 10000,
          "time_window": 300,
          "rejected_code": 429,
          "rejected_msg": "Too many request",
          "show_limit_quota_header": false
        }
      },
      "group_id": "'$TRIAL'"
    }
    '
}

create_consumer_premium() {
  admin_curl_put "consumers" '
  {
    "username": "user3",
    "plugins": {
      "key-auth": {
        "key": "5678"
      }
    },
    "group_id": "'$PREMIUM'"
  }
  '

  admin_curl_put "consumers" '
  {
    "username": "user4",
    "plugins": {
      "key-auth": {
        "key": "8765"
      }
    },
    "group_id": "'$PREMIUM'"
  }
  '

  admin_curl_put "consumers" '
      {
        "username": "no_limit_premium",
        "plugins": {
          "key-auth": {
            "key": "8888"
          },
          "limit-count": {
            "count": 10000,
            "time_window": 300,
            "rejected_code": 429,
            "rejected_msg": "Too many request",
            "show_limit_quota_header": false
          }
        },
        "group_id": "'$PREMIUM'"
      }
      '
}

global_rules() {
  admin_curl_put "global_rules/all" '{
    "prometheus": {
      "prefer_name": true
    }
  }'
}

create() {
  echo "Creating APISIX resources"
  create_upstream
  create_service
  global_rules
  create_routes
  create_consumer_group
  create_consumer_trial
  create_consumer_premium
}

testing() {
  echo "Testing"

  case "$1" in
  free-resources-download)
    api_curl_get "1234" "v1/resources/13229860/download";;
  free-icons-download)
    api_curl_get "4321" "v1/icons/10740624/download";;
  free-download)
    api_curl_get "7777" "v1/download?id=13241130";;
  test-premium-resources-download)
    api_curl_get "5678" "v1/resources/13229860/download";;
  test-premium-icons-download)
    api_curl_get "8765" "v1/icons/10740624/download";;
  test-premium-download)
    api_curl_get "8888" "v1/download?id=13241130";;
  *)
    echo "Invalid option $1"
  esac
}

load_test() {
  echo "$2 Load Test"

  ./vegeta attack -duration=30s -rate=8 -targets=target.list | \
  tee "results_$2.bin" | ./vegeta report

  cat "results_$2.bin" | ./vegeta plot --title="$2 benchmark" > "load_$2.html"
}

load() {
  load_test "$URL" "API"
  load_test "$APISIX_URL" "APISIX"
}

main() {
  command=$1

  case "$command" in
  create)
    create;;
  test)
    testing "$2";;
  load)
    load;;
  *)
    echo "Command not recognized"
  esac
}

main "$@"