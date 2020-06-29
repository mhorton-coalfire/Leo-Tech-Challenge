resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
  auto_create_subnetworks = false
  delete_default_routes_on_create = true
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  target_tags = ["fw-rule"]
}

module "public_subnets" {
  source = "./modules/ha_subnets"
  base_cidr = local.base_cidr
  index = 0
  public = true
  vpc_network_id = google_compute_network.vpc_network.id
}

module "private_subnets" {
  source = "./modules/ha_subnets"
  base_cidr = local.base_cidr
  index = 2
  public = false
  vpc_network_id = google_compute_network.vpc_network.id
}

module "dev_instance" {
  source = "./modules/instance"
  subnet = module.public_subnets.sub_self_link_a
  zone = "us-east1-d" # Todo: Tie region to subnet
  name = "dev"
  tags = ["fw-rule"]
}

module "apache_instance" {
  source = "./modules/instance"
  subnet = module.private_subnets.sub_self_link_a
  zone = "us-east1-d" # Todo: Tie region to subnet
  name = "apache"
  script = file("scripts/startup-apache.sh") # Todo: Install apache
}

module "apache_lb" {
  source = "./modules/lb"
  name = "apache"
  instances = [module.apache_instance.id]
  zone = "us-east1-d" # Todo: Tie region to subnet
}