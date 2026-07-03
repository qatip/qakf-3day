from diagrams import Cluster, Diagram
from diagrams.k8s.compute import Pod, Deployment
from diagrams.k8s.network import Endpoint, Ingress, Service
from diagrams.k8s.group import NS
from diagrams.k8s.storage import PV, PVC, StorageClass

with Diagram("Lab 4 CoreDNS"):
    with Cluster("Kubernetes Cluster"):

        with Cluster("Production NS"):
            fe_svc = Service("Front End ClusterIP")
            fe_dep = Deployment("Front End")
            be_svc = Service("Back End ClusterIP")
            be_dep = Deployment("Back End")

        with Cluster("Development NS"):
            dev_fe_svc = Service("Front End ClusterIP")
            dev_fe_dep = Deployment("Front End")
            dev_be_svc = Service("Back End ClusterIP")
            dev_be_dep = Deployment("Back End")

        fe_svc >> fe_dep >> be_svc >> be_dep
        dev_fe_svc >> dev_fe_dep >> dev_be_svc >> dev_be_dep
