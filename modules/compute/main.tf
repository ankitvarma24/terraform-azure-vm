resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "av-devops-vmss"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "Standard_B2s"

  instances = 2   # ✅ 2 VMs minimum

  admin_username = "azureuser"
  admin_password = var.password

  disable_password_authentication = false

  # SUSE IMAGE
  source_image_reference {
    publisher = "SUSE"
    offer     = "sles-15-sp5"
    sku       = "gen2"
    version   = "latest"
  }

  # INSTALL SCRIPT
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

# AUTO SCALING
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

    # Scale Out
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        operator           = "GreaterThan"
        threshold          = 70
        aggregation        = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
      }
    }

    # Scale In
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        operator           = "LessThan"
        threshold          = 30
        aggregation        = "Average"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
      }
    }
  }
}