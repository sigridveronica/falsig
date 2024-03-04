// Step 1: Define the Package and Import Dependencies
package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Step 2: Define the Asset and Activity Structs
// Asset represents the aircraft being assembled
type Asset struct {
	ACNumber string `json:"acNumber"` // Aircraft number
}

// Activity represents an activity in the assembly line
type Activity struct {
	ActivityID         string `json:"activityID"`
	StartTime          string `json:"startTime"`
	EndTime            string `json:"endTime"`
	StationNumber      int    `json:"stationNumber"`
	MachineID          string `json:"machineID"`
	ToolsOrDrill       string `json:"toolsOrDrill"`
	PartsID            string `json:"partsID"` // Part Number (P/N)
	WorkerID           string `json:"workerID"`
	StationResponsible string `json:"stationResponsible"`
	PreviousStation    string `json:"previousStation"`
	NextStation        string `json:"nextStation"`
}

//Step 3: Implement the Smart Contract

// SmartContract provides functions for managing the assembly line
type SmartContract struct {
	contractapi.Contract
}

// CreateActivity records a new activity in the assembly line
func (s *SmartContract) CreateActivity(ctx contractapi.TransactionContextInterface, activityID string, startTime string, endTime string, stationNumber int, machineID string, toolsOrDrill string, partsID string, workerID string, stationResponsible string, previousStation string, nextStation string) error {
	activity := Activity{
		ActivityID:         activityID,
		StartTime:          startTime,
		EndTime:            endTime,
		StationNumber:      stationNumber,
		MachineID:          machineID,
		ToolsOrDrill:       toolsOrDrill,
		PartsID:            partsID,
		WorkerID:           workerID,
		StationResponsible: stationResponsible,
		PreviousStation:    previousStation,
		NextStation:        nextStation,
	}

	activityJSON, err := json.Marshal(activity)
	if err != nil {
		return fmt.Errorf("failed to marshal activity: %v", err)
	}

	return ctx.GetStub().PutState(activityID, activityJSON)
}

// TransferAsset updates the asset's current station
func (s *SmartContract) TransferAsset(ctx contractapi.TransactionContextInterface, acNumber string, nextStation string) error {
	// Implementation for transferring the asset and validation
	// This is a placeholder for the actual implementation
	return nil
}

//Step 4: Main Function

func main() {
	chaincode, err := contractapi.NewChaincode(new(SmartContract))
	if err != nil {
		fmt.Printf("Error create oemContract chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting oemContract chaincode: %s", err.Error())
	}
}
