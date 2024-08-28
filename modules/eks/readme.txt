Task 5 (EKS)

This part is split into 3 seperate modules as per the sub parts


eks_infra - creates the cluster with the relevant roles and policies.

eks_deployment - deploys a simple pod that contains 
1. nginx demo container
2. nginx-prometheus-exporter
In addition to the relevant services and configmap.

eks_motitoring - deploys prometheus and grafana and supporting resources

all relevant manifests and config files are under ./eks 


Usage
!!Important!! -- Trying to run all 3 modules on the same time will result in validation error (Kubernetes provider can`t validate before cluster in place)
So first run the infra module (regular apply with deploy_to_eks and monitor_eks in false under the root variables.tf)
and after it finishes and eks is up , feel free to run the other two . 

after all 3 modules are applied
1) Hello-world is exposed by Loadbalancer service (default namespace)
2) grafana is expposed by Loadbalancer service (monitoring namespace)

Testing 
1) Tested that browsing to the hello-world service reaches nginx
2) Logged into grafana and verefied that http://prometheus:9090 works as a source (Image attached)

