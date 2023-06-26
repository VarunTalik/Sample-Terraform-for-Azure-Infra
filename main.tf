#Unique Number Generator
resource "random_string" "name" {
    length  = 5
    lower   = false
    numeric = true
    special = false
    upper   = false
}

#Provision Resource Group
resource "azurerm_resource_group" "main" {
    name      = "rg-var-test"
    location  = "West Europe"
}

#Provision Virtual Network
resource "azurerm_virtual_network" "main" {
    name    = "vnet-var"
    address_space = ["10.0.0.0/16"]
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
}

#Provision Private Subnet
resource "azurerm_subnet" "private" {
    name = "subnet-var-private"
    resource_group_name = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes = ["10.0.2.0/24"]
}

#Provision Public Subnet 
resource "azurerm_subnet" "public" {
    name = "subnet-var-public"
    resource_group_name = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes = ["10.0.3.0/24"]
}

#Provision NSG
resource "azurerm_network_security_group" "example" {
  name                = "TestSecurityGroup1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "rule01"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80,443"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

######### Public VM Creation ##########
#Create Public IP
resource "azurerm_public_ip" "main" {
    name = "public-ip-var"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    allocation_method = "Static"
}

#Create Network Interface for public VM
resource "azurerm_network_interface" "public" {
    name = "nic-var-public"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location

    ip_configuration {
      name = "internal-public-var"
      subnet_id = azurerm_subnet.public.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = azurerm_public_ip.main.id
    }
}

resource "azurerm_linux_virtual_machine" "public" {
    name = "test-var-public-machine-${random_string.name.result}"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    size = "Standard_B1ms"
    disable_password_authentication = false
    admin_username = "adminuser"
    admin_password = "Oh_so_$ecre4"
    network_interface_ids = [azurerm_network_interface.public.id,]

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        offer     = "CentOS"
        publisher = "OpenLogic"
        sku       = "7.7"
        version   = "7.7.2021020400"
    }
}

######### Private VMs Creation ##########
#Create Network Interface for private VMs
resource "azurerm_network_interface" "private" {
    name = "nic-var-private-${count.index}"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    count = 2

    ip_configuration {
    name                          = "internal-private-var-${random_string.name.result}-${count.index}"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "private" {
    name = "test-var-private-machine-${random_string.name.result}-${count.index}"
    count = 2
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    size = "Standard_B1ms"
    disable_password_authentication = false
    admin_username = "adminuser"
    admin_password = "Oh_so_$ecre4"
    network_interface_ids = [element(azurerm_network_interface.private.*.id, count.index)]

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        offer     = "CentOS"
        publisher = "OpenLogic"
        sku       = "7.7"
        version   = "7.7.2021020400"
    }
}

# MySQL Creation
resource "azurerm_mysql_server" "main" {
  name                = "my-mysqlserver"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login          = "mysqladminun"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "main" {
  name                = "exampledb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.main.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}