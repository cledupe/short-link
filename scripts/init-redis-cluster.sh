#!/bin/sh
# Redis Cluster Initialization Script
# 
# Waits for all 3 Redis nodes to become available, then forms a 3-node
# Redis cluster by running redis-cli --cluster create.
# Designed to run as a one-shot Docker Compose service.
#
# Usage (in docker-compose.yml):
#   redis-cluster-init:
#     image: redis:7-alpine
#     depends_on:
#       - redis
#     command: sh /scripts/init-redis-cluster.sh
#     volumes:
#       - ./scripts/init-redis-cluster.sh:/scripts/init-redis-cluster.sh

set -e

# Resolve all unique Redis container IPs via Docker DNS
# When scaling with --scale redis=3, "redis" resolves to all 3 container IPs
REDIS_PORT=6379
echo "Resolving Redis nodes via DNS..."

# Collect unique IPs from DNS resolution
REDIS_IPS=$(getent hosts redis | awk '{print $1}' | sort -u)

echo "Found Redis node IPs:"
echo "$REDIS_IPS"

# Build node list for cluster create
NODES=""
for ip in $REDIS_IPS; do
  NODES="$NODES $ip:$REDIS_PORT"
done

echo "Waiting for all Redis nodes to be ready..."

for i in $(seq 1 30); do
  all_ready=true
  for ip in $REDIS_IPS; do
    if ! redis-cli -h "$ip" -p "$REDIS_PORT" ping 2>/dev/null | grep -q PONG; then
      all_ready=false
      break
    fi
  done
  if [ "$all_ready" = true ]; then
    echo "All Redis nodes are ready."
    break
  fi
  echo "Waiting for Redis nodes... attempt $i"
  sleep 2
done

echo "Creating Redis cluster..."
# Creates a 3-master cluster (no replicas). Each node gets a portion of the 16384 hash slots.
# Use --cluster-replicas 1 for production with 6 nodes (3 masters + 3 replicas).
# shellcheck disable=SC2086
redis-cli --cluster create $NODES \
  --cluster-replicas 0 \
  --cluster-yes

echo "Redis cluster created successfully."