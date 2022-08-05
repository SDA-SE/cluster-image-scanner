This folder contains:

- [Deployment of the ClusterScanner Orchestrator](deployment-orchestrator.md)
- [Configuration of the source for the scan process, the repolists](repolist.md)
- [Fetcher](fetcher.md)  

```
argo submit --from cronwf/test-cluster-image-scanner-main -n clusterscanner
```

# Access logs in OpenSearch
https://logging.XXXX/_dashboards/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))&_a=(columns:!(log,stream),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:logstash,key:kubernetes.namespace_name.keyword,negate:!f,params:(query:clusterscanner),type:phrase),query:(match_phrase:(kubernetes.namespace_name.keyword:clusterscanner)))),index:logstash,interval:auto,query:(language:kuery,query:''),sort:!())