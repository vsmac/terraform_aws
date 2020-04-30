# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg_test" {
    name     = "resource_group_test"
    location = "eastus"

    tags = {
        environment = "Terraform Test"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
    name                = "virtual_network_test"
    address_space       = ["10.10.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.rg_test.name

    tags = {
        environment = "Terraform Test"
    }
}

# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "echosubnet"
    resource_group_name  = azurerm_resource_group.rg_test.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.10.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
    name                         = "echoPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.rg_test.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Test"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "security_group" {
    name                = "echoNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.rg_test.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Test"
    }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
    name                      = "echoNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.rg_test.name

    ip_configuration {
        name                          = "echoNicConfiguration"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.publicip.id
    }

    tags = {
        environment = "Terraform Test"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "sg_to_nic" {
    network_interface_id      = azurerm_network_interface.nic.id
    network_security_group_id = azurerm_network_security_group.security_group.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.rg_test.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.rg_test.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Test"
    }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "virtual_machine" {
    name                  = "VM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.rg_test.name
    network_interface_ids = [azurerm_network_interface.nic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    computer_name  = "vmtest"
    admin_username = "ubuntu"
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = "ubuntu"
        public_key     = file("~/.ssh/id_rsa.pub")
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Test"
    }
}
