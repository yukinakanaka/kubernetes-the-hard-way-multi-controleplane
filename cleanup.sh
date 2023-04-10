#!/bin/bash

for i in 'load-balancer-k8s' 'master-1-k8s' 'master-2-k8s' 'worker-1-k8s' 'worker-2-k8s' ; do
  multipass delete "${i}"
done

multipass purge

kubectl config delete-context k8s-the-hard-way
kubectl config delete-cluster k8s-the-hard-way-cluster
kubectl config delete-user    k8s-the-hard-way-admin
