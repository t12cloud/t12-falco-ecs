#!/bin/sh
set -eu

log() {
  echo "[$(date -u +%FT%TZ)] $*"
}

# Required runtime config
: "${ECS_CLUSTER:?ECS_CLUSTER env var is required}"
: "${ECS_SERVICE:?ECS_SERVICE env var is required}"
: "${API_ENDPOINT:?API_ENDPOINT env var is required}"
: "${HEARTBEAT_INTERVAL_SECONDS:=3600}"
: "${CWP_SEC:?CWP_SEC env var is required}"
: "${INTEGRATION_ID:?INTEGRATION_ID env var is required}"
: "${CLUSTER_IDENTIFIER:?CLUSTER_IDENTIFIER env var is required}"
: "${API_KEY:?API_KEY env var is required}"
: "${TENANT_ID:?TENANT_ID env var is required}"
: "${AGENT_ID:?AGENT_ID env var is required}"

get_service_counts() {
  desired="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query "services[0].desiredCount" --output text)"
  running="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query "services[0].runningCount" --output text)"
  echo "$desired" "$running"
}

get_container_laststatus_from_first_task() {
  # We intentionally use the first RUNNING task as a representative signal (cluster-level).
  # If you ever run multiple tasks, we can change this to aggregate.
  container_name="$1"

  task_arns="$(aws ecs list-tasks --cluster "$ECS_CLUSTER" --service-name "$ECS_SERVICE" --desired-status RUNNING --query "taskArns" --output text)"
  if [ -z "$task_arns" ]; then
    echo "unknown"
    return
  fi

  # Use the first task in the list (text output is space-separated)
  first_task="$(echo "$task_arns" | awk '{print $1}')"
  status="$(aws ecs describe-tasks --cluster "$ECS_CLUSTER" --tasks "$first_task" --query "tasks[0].containers[?name==\`$container_name\`].lastStatus | [0]" --output text)"
  echo "$status"
}

post_heartbeat() {
  TS="$(date -u +%FT%TZ)"

  set -- $(get_service_counts)
  DESIRED="$1"
  RUNNING="$2"

  SERVICE_STATUS="degraded"
  if [ "$DESIRED" != "0" ] && [ "$RUNNING" = "$DESIRED" ]; then
    SERVICE_STATUS="ok"
  fi

  FALCO_LAST="$(get_container_laststatus_from_first_task "falco")"
  SIDEKICK_LAST="$(get_container_laststatus_from_first_task "falcosidekick")"
  
  # Send heartbeat (don’t crash loop on temporary errors)
  curl -sS -X POST "$API_ENDPOINT/v1/cwp/agents/$AGENT_ID/heartbeats" \
    -H "Content-Type: application/json" \
    -H "X-CWP-SEC: $CWP_SEC" \
    -H "X-INTEGRATION-ID: $INTEGRATION_ID" \
    -H "X-CLUSTER-IDENTIFIER: $CLUSTER_IDENTIFIER" \
    -H "X-API-KEY: $API_KEY" \
    -H "X-TENANT-ID: $TENANT_ID" \
    -d "{\"agentVersion\":\"1.0\",\"generatedAt\":\"$TS\",\"payload\":{\"desired\": $DESIRED, \"running\": $RUNNING, \"serviceStatus\": \"$SERVICE_STATUS\", \"sideKickLast\": \"$SIDEKICK_LAST\",\"falcoLast\": \"$FALCO_LAST\"}}" || true

  log "heartbeat sent: service_status=$SERVICE_STATUS desired=$DESIRED running=$RUNNING falco=$FALCO_LAST sidekick=$SIDEKICK_LAST"
}

log "heartbeat agent starting (cluster=$ECS_CLUSTER service=$ECS_SERVICE interval=${HEARTBEAT_INTERVAL_SECONDS}s)"
while true; do
  post_heartbeat
  sleep "$HEARTBEAT_INTERVAL_SECONDS"
done