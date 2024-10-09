(* ::Package:: *)


PacletInstall["KirillBelov/CSockets"]; 


BeginPackage["KirillBelov`LabDevicesLink`FBGInterrogator`", {
    "KirillBelov`CSockets`UDP`"
}]; 


FBGInterrogatorData::usage = 
"FBGInterrogatorData[address] get data from FBG Interrogator."; 


Begin["`Private`"];


FBGInterrogatorData::notready = 
"Not ready fo `1` with parameters: {`2`, `3`, `4`}"; 


FBGInterrogatorData::timeout = 
"Reading data from {`2`, `3`, `4`} has exceeded the time limit `1` seconds"; 


Options[FBGInterrogatorData] = {
    "DeviceAddress" -> Automatic, 
    "DevicePort" -> 4567, 
    "PCAddress" -> "127.0.0.1", 
    "PCPort" -> 8001, 
    "Timeout" -> 10, 
    "Channel" -> 0
}; 


FBGInterrogatorData[OptionsPattern[]] := 
Module[{
    deviceAddress = OptionValue["DeviceAddress"], 
    devicePort = OptionValue["DevicePort"], 
    pcAddress = OptionValue["PCAddress"], 
    pcPort = OptionValue["PCPort"], 
    timeout = OptionValue["Timeout"], 
    bag = Internal`Bag[], 
    command = {"10", "04", "04", IntegerString[OptionValue["Channel"], 16, 2]}, 
    commandBytes, 
    data, 
    len, 
    gain, 
    adcData
}, 

    deviceSocket = UDPConnect[deviceAddress, devicePort]; 
    pcSocket = UDPListen[pcAddress, pcPort]; 

    commandBytes = ByteArray[Flatten[Map[FromDigits[#, 16]&, command]]]; 

    If[!UDPReadQ[deviceSocket], 
        Message[FBGInterrogatorData::notready, "write to", deviceAddress, devicePort, deviceSocket]; 
        UDPClose[deviceSocket]; 
        UDPClose[pcSocket]; 
        Return[Null]
    ]; 

    UDPSend[deviceSocket, commandBytes]; 

    TimeConstrained[
        While[!UDPReadyQ[pcSocket], Pause[0.001]], 
        timeout, 
        Message[FBGInterrogatorData::notready, "read from", pcAddress, pcPort, pcSocket]; 
        
        UDPClose[deviceSocket]; 
        UDPClose[pcSocket]; 
        
        Return[Null]
    ]; 

    TimeConstrained[
        While[UDPReadyQ[pcSocket], 
            Internal`StuffBag[bag, UDPRead[pcSocket]]
        ], 
        timeout, 
        Message[FBGInterrogatorData::timeout, timeout, pcAddress, pcPort, pcSocket]; 
        
        UDPClose[deviceSocket]; 
        UDPClose[pcSocket]; 
        
        Return[Null]
    ]; 

    data = Internal`BagPart[bag, All, Join]; 

    UDPClose[deviceSocket]; 
    UDPClose[pcSocket]; 

    len = ImportByteArray[data[[3 ;; 6]], "Integer32", ByteOrdering -> 1][[1]]; 
    gain = ImportByteArray[data[[9 ;; 10]], "Integer16", ByteOrdering -> 1][[1]]; 
    adcData = ImportByteArray[data[[11 ;; ]], "Integer16", ByteOrdering -> 1]; 

    <|
        "CommandLenght" -> len, 
        "ChannelGain" -> gain, 
        "ADCData" -> adcData
    |>
]; 


FBGInterrogatorData[deviceAddress_String, opts: OptionsPattern[]] := 
FBGInterrogatorData["DeviceAddress" -> deviceAddress, opts]; 


End[(*`Private`*)]; 


EndPackage[(*KirillBelov`LabDevicesLink`FBGInterrogator`*)]; 
