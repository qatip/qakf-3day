from diagrams import Cluster, Diagram
from diagrams.k8s.compute import Pod, Deployment
from diagrams.k8s.network import Endpoint, Ingress, Service
from diagrams.k8s.group import NS
from diagrams.k8s.storage import PV, PVC, StorageClass

graph_attr = {
    "bgcolor": "transparent"
}

with Diagram("Lab 4 Ingress", graph_attr=graph_attr):
    with Cluster("Kubernetes Cluster"):
        ing = Ingress("X.nip.io")
        ing_dep = Deployment("Ingress Deployment")

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

        # ing_dep >> ing >> [fe_svc >> fe_dep >> be_svc >> be_dep,
        #                    dev_fe_svc >> dev_fe_dep >> dev_be_svc >> dev_be_dep]
        ing >> dev_fe_svc >> dev_fe_dep >> dev_be_svc >> dev_be_dep
        ing_dep >> ing >> fe_svc >> fe_dep >> be_svc >> be_dep
    
    svc = Service("Ingress NodePort")
    svc >> ing_dep
