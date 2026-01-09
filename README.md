## Login to ecr
```
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/n7c7j1h2
```

## Switch buildx to docker-container
```
docker buildx create --name t12builder --driver docker-container --use
docker buildx inspect --bootstrap
```

## Build the image and push to the repo
```
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t public.ecr.aws/n7c7j1h2/t12/ecs/falco-heartbeat-agent:latest \
  --push .
```

# Running locally

```
docker run --rm -it \
  -v ~/.aws:/root/.aws:ro \
  -e AWS_PROFILE=default -e AWS_SDK_LOAD_CONFIG=1 \
  -e ECS_CLUSTER=demo-cluster \
  -e ECS_SERVICE=t12-falco \
  -e API_ENDPOINT=https://api.t12.io \
  -e CWP_SEC="<CWP_SEC>" \
  -e INTEGRATION_ID="<INTEGRATION_ID>" \
  -e CLUSTER_IDENTIFIER="<CLUSTER_IDENTIFIER>" \
  -e API_KEY="<API_KEY>" \
  -e TENANT_ID="<TENANT_ID>" \
  -e AGENT_ID="<AGENT_ID>" \
  -e HEARTBEAT_INTERVAL_SECONDS="5" \
  t12/ecs/falco-heartbeat-agent:latest
```