(* ::Package:: *)


PacletInstall["KirillBelov/CSockets"]; 


BeginPackage["KirillBelov`LabDevicesLink`FBGInterrogator`", {
    "KirillBelov`CSockets`UDP`"
}]; 


FBGInterrogatorData::usage = 
"FBGInterrogatorData[address] get data from FBG Interrogator."; 


Begin["`Private`"];


FBGInterrogatorData::notready = 
"UDP Socket `1` not ready."; 


Options[FBGInterrogatorData] = {
    "DeviceAddress" -> Automatic, 
    "DevicePort" -> 4567, 
    "PCAddress" -> "127.0.0.1", 
    "PCPort" -> 8001, 
    "Timeout" -> 1, 
    "Command" -> Automatic, 
    "Deserializer" -> Function[#]
}; 


FBGInterrogatorData[OptionsPattern[]] := 
Module[{
    deviceAddress = OptionValue["DeviceAddress"], 
    devicePort = OptionValue["DevicePort"], 
    pcAddress = OptionValue["PCAddress"], 
    pcPort = OptionValue["PCPort"], 
    timeout = OptionValue["Timeout"], 
    bag = Internal`Bag[], 
    command = OptionValue["Command"], 
    deserializer = OptionValue["Deserializer"]
}, 
    commandBytes = hexStringToByteArray[command]; 

    deviceSocket = UDPConnect[deviceAddress, devicePort]; 
    pcSocket = UDPListen[pcAddress, pcPort]; 

    Check[socketWait[deviceSocket, {timeout, N[timeout/100]}], 
        UDPClose[deviceSocket];
        UDPClose[pcSocket];
        Return[Null]
    ];

    UDPSend[deviceSocket, commandBytes]; 

    Check[socketWait[pcSocket, {timeout, N[timeout/100]}], 
        UDPClose[deviceSocket];
        UDPClose[pcSocket];
        Return[Null]
    ]; 

    While[UDPReadyQ[pcSocket], 
        Internal`StuffBag[bag, UDPRead[pcSocket]]; 
        socketWait[pcSocket, {0.01, 0.001}]; 
    ]; 

    UDPClose[deviceSocket];
    UDPClose[pcSocket];

    data = Internal`BagPart[bag, All, Join]; 

    Return[deserializer[data]]
]; 


FBGInterrogatorData[deviceAddress_String, command_String, deserializer_, opts: OptionsPattern[]] := 
FBGInterrogatorData[
    "DeviceAddress" -> deviceAddress, 
    "Command" -> command, 
    "Deserializer" -> deserializer, 
    opts
]; 


FBGInterrogatorData["Commands"] := 
{
    "VersionNumber", 
    "SN",
    "FBGFrequencyData", 
    "ADCRawData"
}; 


FBGInterrogatorData[deviceAddress_String, "VersionNumber", opt: OptionsPattern[]] := 
FBGInterrogatorData[deviceAddress, "10010400", getInteger32[#] / 100.0&, opts]; 


FBGInterrogatorData[deviceAddress_String, "SN", opt: OptionsPattern[]] := 
FBGInterrogatorData[deviceAddress, "10030400", getInteger32, opts]; 


(*... other commands here ... *)


FBGInterrogatorData[deviceAddress_String, "ADCRawData", channelNo_, opt: OptionsPattern[]] := 
FBGInterrogatorData[deviceAddress, "3007060000" <> IntegerString[channelNo, 15, 2], getADCData, opts]; 


(*Internal*)


socketWait[socket_, {period_, interval_}] := 
TimeConstrained[
    While[!UDPReadyQ[socket], Pause[interval]], 
    period, 
    Message[FBGInterrogatorData::notready, socket]; 
    Null
]; 


hexStringToByteArray[hexString_String] := 
ByteArray @ Flatten @ Map[FromDigits[#, 16]&] @ StringPartition[hexString, 2]; 


getInteger32[data_ByteArray] /; Length[data] === 8 := 
ImportByteArray[data[[5 ;; 8]], "Integer32", ByteOrdering -> 1][[1]]; 


getADCData[data_ByteArray] := 
Module[{len, gain, adcData}, 
    len = ImportByteArray[data[[3 ;; 6]], "Integer32", ByteOrdering -> 1][[1]]; 
    gain = ImportByteArray[data[[9 ;; 10]], "Integer16", ByteOrdering -> 1][[1]]; 
    adcData = ImportByteArray[data[[11 ;; ]], "Integer16", ByteOrdering -> 1]; 

    <|
        "CommandLength" -> len, 
        "ChannelGain" -> gain, 
        "ADCData" -> adcData
    |>
]; 


End[(*`Private`*)]; 


EndPackage[(*KirillBelov`LabDevicesLink`FBGInterrogator`*)]; 
