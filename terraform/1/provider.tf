variable "access_key" {}
variable "domain_name" {}

provider "digitalocean" {
  token = "${var.access_key}"
}

resource "digitalocean_ssh_key" "dodemo" {
  name = "DO Demo Key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "digitalocean_droplet" "web" {
  image = "coreos-stable"
  name = "web"
  region = "lon1"
  size = "2gb"
  private_networking = true
  ssh_keys = [ "${digitalocean_ssh_key.dodemo.id}" ]
  user_data = <<USER_DATA
#cloud-config
coreos:
  units:
    - name: "etcd2.service"
      command: "start"
    - name: "fleet.service"
      command: "start"
    - name: "docker-frontend.service"
      command: "start"
      content: |
        [Unit]
        Description=Frontend Service
        Author=Me
        After=docker.service

        [Service]
        Restart=always
        ExecStartPre=-/usr/bin/docker kill frontend
        ExecStartPre=-/usr/bin/docker rm frontend
        ExecStartPre=/usr/bin/docker pull dodockerdemo/frontend
        ExecStart=/usr/bin/docker run -p 80:80 -e API_ROOT_URL=http://$public_ipv4:8080/todo --name frontend dodockerdemo/frontend
        ExecStop=/usr/bin/docker stop frontend
    - name: "docker-backend.service"
      command: "start"
      content: |
        [Unit]
        Description=Backend Service
        Author=Me
        After=docker-cassandra.service

        [Service]
        Restart=always
        ExecStartPre=-/usr/bin/docker kill backend
        ExecStartPre=-/usr/bin/docker rm backend
        ExecStartPre=/usr/bin/docker pull dodockerdemo/backend
        ExecStart=/usr/bin/docker run -p 8080:8080 -e CASSANDRA_CONTACT_POINT=$private_ipv4 --name backend dodockerdemo/backend
        ExecStop=/usr/bin/docker stop backend
    - name: "docker-cassandra.service"
      command: "start"
      content: |
        [Unit]
        Description=Cassandra Service
        Author=Me
        After=docker.service

        [Service]
        Restart=always
        ExecStartPre=-/usr/bin/docker kill cassandra
        ExecStartPre=-/usr/bin/docker rm cassandra
        ExecStartPre=/usr/bin/docker pull cassandra:3.0
        ExecStart=/usr/bin/docker run -p 9042:9042 -v /cassandra_datadir:/var/lib/cassandra --name cassandra cassandra:3.0
        ExecStop=/usr/bin/docker stop cassandra
USER_DATA
}
