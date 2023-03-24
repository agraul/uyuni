# Copyright (c) 2023 SUSE LLC
# Licensed under the terms of the MIT license.

@<client>
Feature: Create bootstrap repositories
  In order to be able to enroll clients with MU repositories
  As the system administrator
  I create all bootstrap repos with --with-custom-channels option

  Scenario: Create the bootstrap repository for <client>
    When I create the bootstrap repository for "<client>" on the server
