resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "av-devops-vmss"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "Standard_B2s"

  instances = 2

  admin_username = "azureuser"
  admin_password = var.password

  disable_password_authentication = false

  source_image_reference {
    publisher = "SUSE"
    offer     = "sles-15-sp5"
    sku       = "gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/../../scripts/install.sh"))

  network_interface {
    name    = "vmss-nic"
    primary = true

   ip_configuration {
  name                                   = "internal"
  subnet_id                              = var.subnet_id
  primary                                = true
  load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bepool.id]
}

  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# ==========================
# AUTO SCALE 
# ==========================
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale-vmss"
  resource_group_name = var.rg_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "default"

    capacity {
      minimum = 2
      maximum = 5
      default = 2
    }

    # SCALE OUT
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # SCALE IN
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}


# PUBLIC IP
resource "azurerm_public_ip" "lb_ip" {
  name                = "av-devops-lb-ip"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# LOAD BALANCER
resource "azurerm_lb" "lb" {
  name                = "av-devops-lb"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "public-ip"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}

# BACKEND POOL
resource "azurerm_lb_backend_address_pool" "bepool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "backend-pool"
}

# HEALTH PROBE
resource "azurerm_lb_probe" "probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "ssh-probe"
  port            = 22
  protocol        = "Tcp"
}

# LB RULE
resource "azurerm_lb_rule" "ssh_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "ssh-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "public-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

#Extension

resource "azurerm_virtual_machine_scale_set_extension" "custom_script" {
  name                         = "customScript"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vmss.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"

  settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/ankitvarma24/terraform-azure-vm/main/scripts/install.sh"
    ]
    commandToExecute = "bash install.sh"
  })
}
}