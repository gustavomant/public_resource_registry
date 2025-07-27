// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "../contracts/PublicResourceRegistry.sol";

contract PublicResourceRegistryTest {
    PublicResourceRegistry public registry;

    function beforeEach() public {
        registry = new PublicResourceRegistry();
    }

    function testResourceNotes() public {
        uint256 lotId = registry.createLot(1000 ether);
        uint256 locId = registry.createLocation("Factory", "Production");
        uint256 itemId = registry.createItem("Product", lotId, 
            PublicResourceRegistry.ItemStatus.Available, 0, locId);
        uint256 serviceId = registry.createService(
            1 ether, 
            "Tech Team", 
            block.timestamp, 
            block.timestamp + 1 days
        );
        uint256 processId = registry.createProcess(
            PublicResourceRegistry.ProcessType.Production,
            locId,
            locId,
            block.timestamp,
            block.timestamp + 1 hours
        );

        uint256[5] memory noteIds = [
            registry.createNote("Lot note"),
            registry.createNote("Location note"),
            registry.createNote("Item note"),
            registry.createNote("Service note"),
            registry.createNote("Process note")
        ];

        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Lot, lotId, noteIds[0]);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Location, locId, noteIds[1]);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Item, itemId, noteIds[2]);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Service, serviceId, noteIds[3]);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Process, processId, noteIds[4]);

        PublicResourceRegistry.ResourceType[5] memory resourceTypes = [
            PublicResourceRegistry.ResourceType.Lot,
            PublicResourceRegistry.ResourceType.Location,
            PublicResourceRegistry.ResourceType.Item,
            PublicResourceRegistry.ResourceType.Service,
            PublicResourceRegistry.ResourceType.Process
        ];

        uint256[5] memory resourceIds = [lotId, locId, itemId, serviceId, processId];

        for (uint i = 0; i < 5; i++) {
            uint256[] memory notes = registry.getResourceNotes(resourceTypes[i], resourceIds[i]);
            Assert.equal(notes.length, 1, "Resource should have 1 note");
            Assert.equal(notes[0], noteIds[i], "Note ID mismatch");
            
            (, string memory content, , ) = registry.notes(noteIds[i]);
            Assert.ok(bytes(content).length > 0, "Note content should exist");
        }
    }

    function testMultipleNotes() public {
        uint256 lotId = registry.createLot(500 ether);
        
        uint256 note1 = registry.createNote("First note");
        uint256 note2 = registry.createNote("Second note");
        uint256 note3 = registry.createNote("Third note");
        
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Lot, lotId, note1);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Lot, lotId, note2);
        registry.attachNoteToResource(PublicResourceRegistry.ResourceType.Lot, lotId, note3);

        uint256[] memory notes = registry.getResourceNotes(
            PublicResourceRegistry.ResourceType.Lot, 
            lotId
        );
        Assert.equal(notes.length, 3, "Should have 3 notes");
    }

    function testCreateLotAndLocation() public {
        uint256 lotId = registry.createLot(1000);
        Assert.equal(lotId, 1, "Lot ID should be 1");

        uint256 locId = registry.createLocation("Main Warehouse", "Storage");
        Assert.equal(locId, 1, "Location ID should be 1");
    }

    function testCreateItemAndVerify() public {
        uint256 lotId = registry.createLot(2000);
        uint256 locId = registry.createLocation("Dock A", "Receiving");

        uint256 itemId = registry.createItem(
            "Widget",
            lotId,
            PublicResourceRegistry.ItemStatus.Available,
            0,
            locId
        );

        (bytes memory itemData) = registry.getResource(
            PublicResourceRegistry.ResourceType.Item,
            itemId
        );
        PublicResourceRegistry.Item memory item = abi.decode(itemData, (PublicResourceRegistry.Item));
        
        Assert.equal(item.name, "Widget", "Item name should match");
    }

    function testProcessLifecycleWithItems() public {
        uint256 lotId = registry.createLot(500);
        uint256 fromLoc = registry.createLocation("Start", "Dock");
        uint256 toLoc = registry.createLocation("End", "Warehouse");

        uint256 itemId = registry.createItem("Box", lotId, PublicResourceRegistry.ItemStatus.Available, 0, fromLoc);
        uint256 processId = registry.createProcess(
            PublicResourceRegistry.ProcessType.Transportation,
            fromLoc,
            toLoc,
            block.timestamp,
            block.timestamp + 3600
        );

        registry.addItemToProcess(processId, itemId);
        Assert.equal(registry.getProcessItems(processId).length, 1, "Process should have 1 item");

        registry.startProcess(processId);
        (bytes memory processData) = registry.getResource(
            PublicResourceRegistry.ResourceType.Process,
            processId
        );
        PublicResourceRegistry.Process memory proc = abi.decode(processData, (PublicResourceRegistry.Process));
        Assert.equal(uint(proc.status), uint(PublicResourceRegistry.ProcessStatus.InProgress), "Process should be InProgress");

        registry.completeProcess(processId);
        proc = abi.decode(registry.getResource(PublicResourceRegistry.ResourceType.Process, processId), (PublicResourceRegistry.Process));
        Assert.equal(uint(proc.status), uint(PublicResourceRegistry.ProcessStatus.Completed), "Process should be Completed");
    }

    function testServiceLifecycle() public {
        uint256 serviceId = registry.createService(
            500,
            "MaintenanceTeam",
            block.timestamp,
            block.timestamp + 3600
        );

        (bytes memory serviceData) = registry.getResource(
            PublicResourceRegistry.ResourceType.Service,
            serviceId
        );
        PublicResourceRegistry.Service memory service = abi.decode(serviceData, (PublicResourceRegistry.Service));
        Assert.equal(uint(service.status), uint(PublicResourceRegistry.ServiceStatus.Requested), "Initial status should be Requested");

        registry.startService(serviceId);
        service = abi.decode(registry.getResource(PublicResourceRegistry.ResourceType.Service, serviceId), (PublicResourceRegistry.Service));
        Assert.equal(uint(service.status), uint(PublicResourceRegistry.ServiceStatus.InProgress), "Status should be InProgress");

        registry.completeService(serviceId);
        service = abi.decode(registry.getResource(PublicResourceRegistry.ResourceType.Service, serviceId), (PublicResourceRegistry.Service));
        Assert.equal(uint(service.status), uint(PublicResourceRegistry.ServiceStatus.Completed), "Status should be Completed");
    }

    function testResourceCounts() public {
        uint256 initialItems = registry.getResourceCount(PublicResourceRegistry.ResourceType.Item);
        uint256 initialLots = registry.getResourceCount(PublicResourceRegistry.ResourceType.Lot);

        registry.createLot(100 ether);
        registry.createItem("Test", 1, PublicResourceRegistry.ItemStatus.Available, 0, 0);

        Assert.equal(
            registry.getResourceCount(PublicResourceRegistry.ResourceType.Lot),
            initialLots + 1,
            "Lot count should increment"
        );
        Assert.equal(
            registry.getResourceCount(PublicResourceRegistry.ResourceType.Item),
            initialItems + 1,
            "Item count should increment"
        );
    }
}