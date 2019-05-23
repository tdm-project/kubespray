output "k8s_master_ext_net_ips" {    
  value = ["${openstack_compute_instance_v2.k8s_master_ext_net.*.network.0.fixed_ip_v4}"]
}

output "k8s_node_ext_net_ips" {
  value = ["${openstack_compute_instance_v2.k8s_node_ext_net.*.network.0.fixed_ip_v4}", "${openstack_compute_instance_v2.k8s_data_node_ext_net.*.network.0.fixed_ip_v4}"]
}