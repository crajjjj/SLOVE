{
  SLOVE_UBE_TonguePatch
  ---------------------
  Generates a patch plugin that makes SLO VE's worn tongue armors (the 10
  bundled HALO HDT "linga" tongues, SLOVE_Tongue1Armor..10Armor) render on
  UBE (UBE_AllRace.esp) custom-race actors.

  WHY: a worn armor's mesh only shows on the races listed in its Armor Addon
  (ARMA) "Additional Races". SLO VE's tongue armatures list the vanilla /
  DLC races only, so an equipped tongue is INVISIBLE when the wearer is a
  UBE custom race (Breton/Imperial/Nord/Redguard/Dark Elf/High Elf/Wood Elf/
  Orc plus their vampire variants and 2 custom races). This script sweeps the
  SLO VE tongue armors, copies their armatures into a patch, and adds every
  UBE race to their Additional Races. Shared armatures are de-duped.

  The tongue is head-attached (NPC Head bone + the tong1 HDT chain), NOT
  body-conforming - so it needs ONLY this race-coverage fix, no UBE-specific
  (!UBE\...) mesh conversion. This mirrors the Beeing Female NG "BF UBE
  Patch" approach for its worn slings/panties.

  HOW TO RUN (SSEEdit / xEdit):
    1. Copy this file into your xEdit "Edit Scripts" folder
       (next to SSEEdit.exe), OR use Apply Script -> paste.
    2. Launch xEdit, load your full load order. Both
       SLOVE.esp and UBE_AllRace.esp MUST be ticked.
    3. Wait for "Background Loader: finished".
    4. Right-click any record in the left pane -> "Apply Script...".
    5. Select "SLOVE UBE Patch", click OK.
    6. When prompted to create a new file, name it
       SLOVE_UBE_Support.esp (or accept the default).
       If asked to add masters, click Yes.
    7. Ctrl+S, tick SLOVE_UBE_Support.esp, Save.
    8. In your mod manager, enable SLOVE_UBE_Support.esp and let it load
       AFTER SLOVE.esp and UBE_AllRace.esp.

  NOTE: this is override-only - safe to ESL-flag (espfe). It does NOT edit
  SLOVE.esp itself, only re-asserts its tongue armatures with UBE races added.
}
unit SLOVE_UBE_Patch;

const
  SLOVE_PLUGIN = 'SLOVE.esp';
  UBE_PLUGIN   = 'UBE_AllRace.esp';
  PATCH_NAME   = 'SLOVE_UBE_Support.esp';
  TONGUE_EDID  = 'SLOVE_TONGUE';   // ARMO EditorID prefix (SLOVE_Tongue1Armor..)

var
  sloveFile, ubeFile, patchFile, ubeRaceGrp : IInterface;
  armaDone : TStringList;

function FindFile(aName: string): IInterface;
var
  i: Integer;
  f: IInterface;
begin
  Result := nil;
  for i := 0 to FileCount - 1 do begin
    f := FileByIndex(i);
    if SameText(GetFileName(f), aName) then begin
      Result := f;
      Break;
    end;
  end;
end;

procedure AddRacesToArma(arma: IInterface);
var
  armaOvr, addRaces, entry, raceRec: IInterface;
  i, j: Integer;
  key, fidHex: string;
  already: Boolean;
begin
  key := IntToHex(GetLoadOrderFormID(arma), 8);
  if armaDone.IndexOf(key) >= 0 then Exit;
  armaDone.Add(key);

  armaOvr := wbCopyElementToFile(arma, patchFile, False, True);
  if not Assigned(armaOvr) then begin
    AddMessage('  ! could not copy ARMA ' + key);
    Exit;
  end;

  addRaces := ElementByPath(armaOvr, 'Additional Races');
  if not Assigned(addRaces) then
    addRaces := Add(armaOvr, 'Additional Races', True);

  for i := 0 to ElementCount(ubeRaceGrp) - 1 do begin
    raceRec := ElementByIndex(ubeRaceGrp, i);
    if Signature(raceRec) <> 'RACE' then Continue;
    fidHex := IntToHex(GetLoadOrderFormID(raceRec), 8);

    already := False;
    for j := 0 to ElementCount(addRaces) - 1 do begin
      entry := ElementByIndex(addRaces, j);
      if SameText(IntToHex(GetNativeValue(entry), 8), fidHex) then begin
        already := True;
        Break;
      end;
    end;
    if already then Continue;

    entry := ElementAssign(addRaces, HighInteger, nil, False);
    SetEditValue(entry, fidHex);
  end;

  AddMessage('  patched ARMA ' + key + '  (' + GetElementEditValues(armaOvr, 'EDID') + ')');
end;

function Initialize: Integer;
var
  i, j, armoCount, patchedArma: Integer;
  armoGrp, armo, armature, armaRef, arma: IInterface;
  edid: string;
begin
  Result := 0;

  sloveFile := FindFile(SLOVE_PLUGIN);
  ubeFile   := FindFile(UBE_PLUGIN);
  if not Assigned(sloveFile) then begin
    AddMessage('ERROR: ' + SLOVE_PLUGIN + ' is not loaded.'); Result := 1; Exit;
  end;
  if not Assigned(ubeFile) then begin
    AddMessage('ERROR: ' + UBE_PLUGIN + ' is not loaded.'); Result := 1; Exit;
  end;

  ubeRaceGrp := GroupBySignature(ubeFile, 'RACE');
  if not Assigned(ubeRaceGrp) or (ElementCount(ubeRaceGrp) = 0) then begin
    AddMessage('ERROR: no RACE records found in ' + UBE_PLUGIN); Result := 1; Exit;
  end;

  patchFile := FindFile(PATCH_NAME);
  if not Assigned(patchFile) then
    patchFile := AddNewFile; // name it SLOVE_UBE_Support.esp in the dialog
  if not Assigned(patchFile) then begin
    AddMessage('ERROR: no patch file created.'); Result := 1; Exit;
  end;
  AddMasterIfMissing(patchFile, SLOVE_PLUGIN);
  AddMasterIfMissing(patchFile, UBE_PLUGIN);
  // The tongue armatures list vanilla (and DLC) races in Additional Races.
  // Add those game masters up front so the deep copy can map them (otherwise:
  // "FileID [00] can not be mapped"). Only added if actually loaded; run
  // "Clean Masters" later to trim any unused.
  if Assigned(FindFile('Skyrim.esm'))      then AddMasterIfMissing(patchFile, 'Skyrim.esm');
  if Assigned(FindFile('Update.esm'))      then AddMasterIfMissing(patchFile, 'Update.esm');
  if Assigned(FindFile('Dawnguard.esm'))   then AddMasterIfMissing(patchFile, 'Dawnguard.esm');
  if Assigned(FindFile('HearthFires.esm')) then AddMasterIfMissing(patchFile, 'HearthFires.esm');
  if Assigned(FindFile('Dragonborn.esm'))  then AddMasterIfMissing(patchFile, 'Dragonborn.esm');

  armaDone := TStringList.Create;
  armoCount := 0;
  try
    // Sweep the SLO VE tongue armors (ARMO EditorID SLOVE_Tongue*Armor). Each
    // one's Armor Addon gets its Additional Races opened up to the UBE races.
    // Shared armatures are de-duped, so each ARMA is patched once.
    armoGrp := GroupBySignature(sloveFile, 'ARMO');
    if not Assigned(armoGrp) then begin
      AddMessage('ERROR: no ARMO group in ' + SLOVE_PLUGIN); Result := 1; Exit;
    end;
    for i := 0 to ElementCount(armoGrp) - 1 do begin
      armo := ElementByIndex(armoGrp, i);
      if Signature(armo) <> 'ARMO' then Continue;
      edid := GetElementEditValues(armo, 'EDID');
      if Pos(TONGUE_EDID, UpperCase(edid)) <> 1 then Continue;
      armature := ElementByPath(armo, 'Armature');
      if not Assigned(armature) or (ElementCount(armature) = 0) then Continue;
      AddMessage('ARMO ' + IntToHex(GetLoadOrderFormID(armo) and $00FFFFFF, 6)
        + '  (' + edid + ')');
      for j := 0 to ElementCount(armature) - 1 do begin
        armaRef := ElementByIndex(armature, j);
        arma := LinksTo(armaRef);
        if Assigned(arma) then
          AddRacesToArma(WinningOverride(arma));
      end;
      Inc(armoCount);
    end;
    patchedArma := armaDone.Count;
  finally
    armaDone.Free;
  end;

  AddMessage('DONE. Swept ' + IntToStr(armoCount) + ' tongue armors, patched '
    + IntToStr(patchedArma) + ' armatures (+UBE races).');
  AddMessage('TIP: this is override-only - safe to ESL-flag. In the File Header,');
  AddMessage('     tick the ESL flag (Record Flags), then Save, to make it espfe.');
  AddMessage('Save ' + PATCH_NAME + ', then enable it after SLOVE.esp and ' + UBE_PLUGIN + '.');
end;

end.
