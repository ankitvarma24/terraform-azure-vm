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
      name      = "internal"
      subnet_id = var.subnet_id
      primary   = true
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# ==========================
# AUTO SCALE (FIXED VERSION)
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