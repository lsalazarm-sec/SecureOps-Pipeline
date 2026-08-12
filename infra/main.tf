# infra/main.tf
# Purpose: Provision the baseline network, firewall (NSG), and VM for the DevSecOps lab.

# 1. Fetch Local Public IP dynamically
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  admin_ip = "${chomp(data.http.myip.response_body)}/32"
}

# 2. Resource Group for the Infrastructure
resource "azurerm_resource_group" "infra_rg" {
  name     = "rg-secureops-infra"
  location = "eastus"
}

# 3. Virtual Network and Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-secureops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.infra_rg.location
  resource_group_name = azurerm_resource_group.infra_rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-secureops"
  resource_group_name  = azurerm_resource_group.infra_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Network Security Group (The Firewall) - Principle of Least Privilege
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-secureops"
  location            = azurerm_resource_group.infra_rg.location
  resource_group_name = azurerm_resource_group.infra_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.admin_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-K8s-API"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = local.admin_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 5. Public IP and Network Interface
resource "azurerm_public_ip" "pip" {
  name                = "pip-secureops-vm"
  location            = azurerm_resource_group.infra_rg.location
  resource_group_name = azurerm_resource_group.infra_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-secureops-vm"
  location            = azurerm_resource_group.infra_rg.location
  resource_group_name = azurerm_resource_group.infra_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 6. Virtual Machine (Ubuntu 24.04)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-secureops"
  resource_group_name = azurerm_resource_group.infra_rg.name
  location            = azurerm_resource_group.infra_rg.location
  size                = "Standard_B2s" 
  admin_username      = "devsecops"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "devsecops"
    public_key = file("ephemeral_ssh_key.pub") 
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" 
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# 7. Output the Public IP so we know where to connect later
output "vm_public_ip" {
  value       = azurerm_linux_virtual_machine.vm.public_ip_address
  description = "The public IP address of the newly created VM."
}
