# Copyright (c) 2018-2022 SUSE LLC
# Licensed under the terms of the MIT license.

@buildhost
@scope_building_container_images
@auth_registry
Feature: Build image with authenticated registry

  Scenario: Log in as docker user
    Given I am authorized as "docker" with password "docker"
    And I am logged in API as user "docker" and password "docker"

  Scenario: Create an authenticated image store as Docker admin
    When I follow the left menu "Images > Stores"
    And I follow "Create"
    And I enter "auth_registry" as "label"
    And I check "useCredentials"
    And I enter URI, username and password for registry
    And I click on "create-btn"
    Then I wait until I see "registry" text

  Scenario: Create a profile for the authenticated image store as Docker admin
    When I follow the left menu "Images > Profiles"
    And I follow "Create"
    And I enter "auth_registry_profile" as "label"
    And I select "auth_registry" from "imageStore"
    And I select "1-DOCKER-TEST" from "activationKey"
    And I enter "Docker/authprofile" relative to profiles as "path"
    And I click on "create-btn"
    Then I wait until I see "auth_registry_profile" text

  Scenario: Build an image in the authenticated image store
    When I follow the left menu "Images > Build"
    And I select "auth_registry_profile" from "profileId"
    And I enter "latest" as "version"
    And I select the hostname of "build_host" from "buildHostId"
    And I click on "submit-btn"
    Then I wait until I see "auth_registry_profile" text
    # Verify the status of images in the authenticated image store
    When I wait at most 660 seconds until container "auth_registry_profile" is built successfully
    And I refresh the page
    Then table row for "auth_registry_profile" should contain "1"

  Scenario: Cleanup: remove Docker profile for the authenticated image store
    When I follow the left menu "Images > Profiles"
    And I check the row with the "auth_registry_profile" text
    And I click on "Delete"
    And I click on the red confirmation button
    And I should see a "Image profile has been deleted." text

  Scenario: Cleanup: remove authenticated image store
    When I follow the left menu "Images > Stores"
    And I check the row with the "auth_registry" text
    And I click on "Delete"
    And I click on the red confirmation button
    And I should see a "Image store has been deleted." text

  Scenario: Cleanup: delete registry image
    When I delete the image "auth_registry_profile" with version "latest" via API calls
    And I logout from API
