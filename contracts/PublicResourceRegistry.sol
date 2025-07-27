// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PublicResourceRegistry {
    uint256 public constant MAX_ITEMS_PER_PROCESS = 50;
    uint256 public constant MAX_STRING_LENGTH = 128;
    uint256 public constant MAX_COMPONENTS_PER_ITEM = 50;

    enum ResourceType { Item, Lot, Service, Note, Process, Location }
    enum ItemStatus { Available, InUse }
    enum ProcessType { Maintenance, Production, Inspection, Transportation }
    enum ProcessStatus { Created, InProgress, Completed }
    enum ServiceStatus { Requested, InProgress, Completed }

    struct Item {
        uint256 id;
        string name;
        uint256 lotId;
        uint256 currentLocationId;
        uint256 currentProcessId;
        uint256 originProcessId;
        ItemStatus status;
        uint256 timestamp;
        address createdBy;
    }
    
    struct Lot {
        uint256 id;
        uint256 cost;
        uint256 timestamp;
        address createdBy;
    }
    
    struct Service {
        uint256 id;
        uint256 cost;
        ServiceStatus status;
        string responsibleParty;
        uint256 expectedStart;
        uint256 expectedEnd;
        uint256 actualStart;
        uint256 actualEnd;
        uint256 timestamp;
        address createdBy;
    }
    
    struct Note {
        uint256 id;
        string content;
        uint256 timestamp;
        address createdBy;
    }
    
    struct Process {
        uint256 id;
        ProcessType processType;
        ProcessStatus status;
        uint256 fromLocationId;
        uint256 toLocationId;
        uint256 expectedStart;
        uint256 expectedEnd;
        uint256 actualStart;
        uint256 actualEnd;
        uint256 timestamp;
        address createdBy;
    }
    
    struct Location {
        uint256 id;
        string name;
        string locationType;
        uint256 timestamp;
        address createdBy;
    }

    uint256 public nextItemId = 1;
    uint256 public nextLotId = 1;
    uint256 public nextServiceId = 1;
    uint256 public nextNoteId = 1;
    uint256 public nextProcessId = 1;
    uint256 public nextLocationId = 1;

    mapping(uint256 => Item) public items;
    mapping(uint256 => Lot) public lots;
    mapping(uint256 => Service) public services;
    mapping(uint256 => Note) public notes;
    mapping(uint256 => Process) public processes;
    mapping(uint256 => Location) public locations;
    
    mapping(uint256 => uint256[]) public itemComponents;
    mapping(uint256 => uint256[]) public itemNotes;
    mapping(uint256 => uint256[]) public lotNotes;
    mapping(uint256 => uint256[]) public serviceNotes;
    mapping(uint256 => uint256[]) public processNotes;
    mapping(uint256 => uint256[]) public locationNotes;
    mapping(uint256 => uint256[]) public processServices;
    mapping(uint256 => uint256[]) public processItems;
    mapping(uint256 => bool) public isComponent;
    mapping(address => mapping(ResourceType => bool)) public permissions;
    
    address public owner;

    error OnlyOwner();
    error NoPermission();
    error StringTooLong();
    error NotFound();
    error ExceedsLimit();
    error InvalidStatus();
    error InvalidLocation();
    error InvalidProcess();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier hasPermission(ResourceType resourceType) {
        if (!(permissions[msg.sender][resourceType] || msg.sender != owner)) 
            revert NoPermission();
        _;
    }

    modifier validString(string memory str) {
        if (bytes(str).length > MAX_STRING_LENGTH) revert StringTooLong();
        _;
    }

    constructor() {
        owner = msg.sender;
        // Automatically grant the owner permissions for all resource types
        for (uint i = 0; i <= uint(ResourceType.Location); i++) {
            permissions[owner][ResourceType(i)] = true;
        }
    }

    function grantPermission(address userAddress, ResourceType resourceType) external onlyOwner {
        permissions[userAddress][resourceType] = true;
    }

    function createItem(
        string memory name,
        uint256 lotId,
        ItemStatus status,
        uint256 originProcessId,
        uint256 currentLocationId
    ) external hasPermission(ResourceType.Item) validString(name) returns (uint256) {
        if (lots[lotId].id == 0) revert NotFound();
        if (originProcessId != 0 && processes[originProcessId].id == 0) revert NotFound();
        if (currentLocationId != 0 && locations[currentLocationId].id == 0) revert NotFound();
        
        uint256 id = nextItemId++;
        items[id] = Item({
            id: id,
            name: name,
            lotId: lotId,
            currentLocationId: currentLocationId,
            currentProcessId: 0,
            originProcessId: originProcessId,
            status: status,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function createLot(uint256 cost) external hasPermission(ResourceType.Lot) returns (uint256) {
        uint256 id = nextLotId++;
        lots[id] = Lot({
            id: id,
            cost: cost,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function createService(
        uint256 cost,
        string memory responsibleParty,
        uint256 expectedStart,
        uint256 expectedEnd
    ) external hasPermission(ResourceType.Service) validString(responsibleParty) returns (uint256) {
        uint256 id = nextServiceId++;
        services[id] = Service({
            id: id,
            cost: cost,
            status: ServiceStatus.Requested,
            responsibleParty: responsibleParty,
            expectedStart: expectedStart,
            expectedEnd: expectedEnd,
            actualStart: 0,
            actualEnd: 0,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function createNote(string memory content) external hasPermission(ResourceType.Note) validString(content) returns (uint256) {
        uint256 id = nextNoteId++;
        notes[id] = Note({
            id: id,
            content: content,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function createProcess(
        ProcessType processType,
        uint256 fromLocationId,
        uint256 toLocationId,
        uint256 expectedStart,
        uint256 expectedEnd
    ) external hasPermission(ResourceType.Process) returns (uint256) {
        if (processType == ProcessType.Transportation) {
            if (locations[fromLocationId].id == 0) revert InvalidLocation();
            if (locations[toLocationId].id == 0) revert InvalidLocation();
        }
        
        uint256 id = nextProcessId++;
        processes[id] = Process({
            id: id,
            processType: processType,
            status: ProcessStatus.Created,
            fromLocationId: fromLocationId,
            toLocationId: toLocationId,
            expectedStart: expectedStart,
            expectedEnd: expectedEnd,
            actualStart: 0,
            actualEnd: 0,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function createLocation(
        string memory name,
        string memory locationType
    ) external hasPermission(ResourceType.Location) validString(name) validString(locationType) returns (uint256) {
        uint256 id = nextLocationId++;
        locations[id] = Location({
            id: id,
            name: name,
            locationType: locationType,
            timestamp: block.timestamp,
            createdBy: msg.sender
        });
        return id;
    }

    function attachNoteToResource(ResourceType resourceType, uint256 entityId, uint256 noteId) external {
        if (notes[noteId].id == 0) revert NotFound();
        if (!(permissions[msg.sender][resourceType] || msg.sender != owner)) revert NoPermission();
        
        if (resourceType == ResourceType.Item) {
            if (items[entityId].id == 0) revert NotFound();
            itemNotes[entityId].push(noteId);
        } else if (resourceType == ResourceType.Lot) {
            if (lots[entityId].id == 0) revert NotFound();
            lotNotes[entityId].push(noteId);
        } else if (resourceType == ResourceType.Service) {
            if (services[entityId].id == 0) revert NotFound();
            serviceNotes[entityId].push(noteId);
        } else if (resourceType == ResourceType.Process) {
            if (processes[entityId].id == 0) revert NotFound();
            processNotes[entityId].push(noteId);
        } else if (resourceType == ResourceType.Location) {
            if (locations[entityId].id == 0) revert NotFound();
            locationNotes[entityId].push(noteId);
        } else {
            revert NoPermission();
        }
    }

    function addComponentToItem(uint256 itemId, uint256 componentId) external {
        if (items[itemId].createdBy != msg.sender) revert NoPermission();
        if (items[componentId].id == 0) revert NotFound();
        if (itemComponents[itemId].length >= MAX_COMPONENTS_PER_ITEM) revert ExceedsLimit();
        
        itemComponents[itemId].push(componentId);
        isComponent[componentId] = true;
    }

    function addServiceToProcess(uint256 processId, uint256 serviceId) external {
        if (processes[processId].id == 0) revert NotFound();
        if (services[serviceId].id == 0) revert NotFound();
        if (processes[processId].status != ProcessStatus.Created) revert InvalidStatus();
        if (services[serviceId].status != ServiceStatus.Requested) revert InvalidStatus();
        
        processServices[processId].push(serviceId);
    }

    function addItemToProcess(uint256 processId, uint256 itemId) external {
        if (processes[processId].id == 0) revert NotFound();
        if (items[itemId].id == 0) revert NotFound();
        if (processes[processId].status != ProcessStatus.Created) revert InvalidStatus();
        if (items[itemId].status != ItemStatus.Available) revert InvalidStatus();
        if (processItems[processId].length >= MAX_ITEMS_PER_PROCESS) revert ExceedsLimit();
        
        processItems[processId].push(itemId);
    }

    function startService(uint256 serviceId) external hasPermission(ResourceType.Service) {
        if (services[serviceId].status != ServiceStatus.Requested) revert InvalidStatus();
        services[serviceId].status = ServiceStatus.InProgress;
        services[serviceId].actualStart = block.timestamp;
    }

    function completeService(uint256 serviceId) external hasPermission(ResourceType.Service) {
        if (services[serviceId].status != ServiceStatus.InProgress) revert InvalidStatus();
        services[serviceId].status = ServiceStatus.Completed;
        services[serviceId].actualEnd = block.timestamp;
    }

    function startProcess(uint256 processId) external hasPermission(ResourceType.Process) {
        if (processes[processId].status != ProcessStatus.Created) revert InvalidStatus();
        processes[processId].status = ProcessStatus.InProgress;
        processes[processId].actualStart = block.timestamp;
        
        if (processes[processId].processType == ProcessType.Transportation) {
            uint256[] memory itemsInProcess = processItems[processId];
            for (uint i = 0; i < itemsInProcess.length; i++) {
                items[itemsInProcess[i]].currentProcessId = processId;
                items[itemsInProcess[i]].status = ItemStatus.InUse;
            }
        }
    }

    function completeProcess(uint256 processId) external hasPermission(ResourceType.Process) {
        if (processes[processId].status != ProcessStatus.InProgress) revert InvalidStatus();
        processes[processId].status = ProcessStatus.Completed;
        processes[processId].actualEnd = block.timestamp;
        
        if (processes[processId].processType == ProcessType.Transportation) {
            uint256[] memory itemsInProcess = processItems[processId];
            for (uint i = 0; i < itemsInProcess.length; i++) {
                items[itemsInProcess[i]].currentLocationId = processes[processId].toLocationId;
                items[itemsInProcess[i]].currentProcessId = 0;
                
                if (!isComponent[itemsInProcess[i]]) {
                    items[itemsInProcess[i]].status = ItemStatus.Available;
                }
            }
        }
    }

    function getResource(ResourceType resourceType, uint256 id) public view returns (bytes memory) {
        if (resourceType == ResourceType.Item) {
            return abi.encode(items[id]);
        } else if (resourceType == ResourceType.Lot) {
            return abi.encode(lots[id]);
        } else if (resourceType == ResourceType.Service) {
            return abi.encode(services[id]);
        } else if (resourceType == ResourceType.Note) {
            return abi.encode(notes[id]);
        } else if (resourceType == ResourceType.Process) {
            return abi.encode(processes[id]);
        } else if (resourceType == ResourceType.Location) {
            return abi.encode(locations[id]);
        }
        revert("Invalid resource type");
    }

    function getResourceCount(ResourceType resourceType) public view returns (uint256) {
        if (resourceType == ResourceType.Item) {
            return nextItemId - 1;
        } else if (resourceType == ResourceType.Lot) {
            return nextLotId - 1;
        } else if (resourceType == ResourceType.Service) {
            return nextServiceId - 1;
        } else if (resourceType == ResourceType.Note) {
            return nextNoteId - 1;
        } else if (resourceType == ResourceType.Process) {
            return nextProcessId - 1;
        } else if (resourceType == ResourceType.Location) {
            return nextLocationId - 1;
        }
        revert("Invalid resource type");
    }

    function getItemComponents(uint256 itemId) public view returns (uint256[] memory) {
        return itemComponents[itemId];
    }

    function getProcessItems(uint256 processId) public view returns (uint256[] memory) {
        return processItems[processId];
    }

    function getProcessServices(uint256 processId) public view returns (uint256[] memory) {
        return processServices[processId];
    }

    function getResourceNotes(ResourceType resourceType, uint256 resourceId) public view returns (uint256[] memory) {
        if (resourceType == ResourceType.Item) {
            return itemNotes[resourceId];
        } else if (resourceType == ResourceType.Lot) {
            return lotNotes[resourceId];
        } else if (resourceType == ResourceType.Service) {
            return serviceNotes[resourceId];
        } else if (resourceType == ResourceType.Process) {
            return processNotes[resourceId];
        } else if (resourceType == ResourceType.Location) {
            return locationNotes[resourceId];
        }
        revert("Invalid resource type for notes");
    }
}