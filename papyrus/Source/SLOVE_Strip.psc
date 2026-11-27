Scriptname SLOVE_Strip Hidden
{Procedural stripping: take off only what lies on the body zone an act uses, at
 the moment the act begins, and put it back when the scene ends.

 SLOVE.dll finds the armors (skse\src\Strip.cpp): it reads the actor's loaded 3D
 and counts, for every worn armor, the vertices weighted to the zone's bones
 (labia, anus, genitals, breasts) and the vertices that lie within reach of the
 opening, measured at rest on the pelvis, the upper spine or (the mouth) the head. An item with enough
 of either is in the way. The body itself, a schlong or strap-on, a tongue, a nameless item,
 a SexLabNoStrip or Devious Devices item and a kept slot are never reported.

 This script is the framework-free half: it unequips what the DLL names, keeps
 the list on the actor, and re-equips it. WHEN a zone comes into play is
 SLOVE_Director's call (its StripPass), the only place that reads the scene.

 State, all under the SLOVE_Strip prefix (StorageUtil):
   on the actor   SLOVE_StripZones    zones already uncovered this scene
                  SLOVE_StripItems    what was taken off, in order
                  SLOVE_StripRedress  1 = put it back at scene end
   on None        SLOVE_StripActors   every actor with any of the above
 RestoreAll clears all of it, at every scene end and on a load with no scene.}

;---------------- natives (SLOVE.dll 0.7.17+) ----------------

;The worn armors that lie on aiZones. afReach = how far around an opening an item
;counts (game units; 0 = bone weights only). aiKeepSlots = slot mask never touched.
Form[] Function FindBlocking(Actor akActor, Int aiZones, Float afReach, Int aiKeepSlots) native global

;One line per worn armor: what it covers and why it is kept, for the console.
String[] Function DescribeWorn(Actor akActor, Float afReach, Int aiKeepSlots) native global

;---------------- zones ----------------

Int Function ZoneVagina() Global
	return 1
EndFunction

Int Function ZoneAnus() Global
	return 2
EndFunction

Int Function ZonePenis() Global
	return 4
EndFunction

Int Function ZoneBreasts() Global
	return 8
EndFunction

Int Function ZoneMouth() Global
	return 16
EndFunction

;The natives above came with SLOVE.dll 0.7.17 (major<<24 | minor<<16 | patch<<4).
;An older DLL would log an unbound native on every call.
Bool Function Available() Global
	return SKSE.GetPluginVersion("SLOVE") >= 0x00070110
EndFunction

;"52, 49" -> the slot mask of biped slots 52 and 49. Anything that is not a slot
;number from 30 to 61 is ignored.
Int Function SlotMask(String asSlots) Global
	int mask = 0
	if asSlots == ""
		return mask
	endif
	String[] parts = PapyrusUtil.StringSplit(asSlots, ",")
	int i = 0
	while i < parts.Length
		int slot = parts[i] as int
		if slot >= 30 && slot <= 61
			mask = Math.LogicalOr(mask, Math.LeftShift(1, slot - 30))
		endif
		i += 1
	endwhile
	return mask
EndFunction

;---------------- strip ----------------

;The zones already uncovered on this actor in the running scene.
Int Function DoneZones(Actor akActor) Global
	return StorageUtil.GetIntValue(akActor, "SLOVE_StripZones", 0)
EndFunction

;Take off what lies on aiZones. Returns how many items came off, or -1 when the
;actor cannot be read right now (no 3D): ask again on a later pass.
;A zone is handled once per scene, also when nothing lay on it.
Int Function Uncover(Actor akActor, Int aiZones, Float afReach, Int aiKeepSlots, Bool abRedress) Global
	if !akActor || aiZones == 0
		return 0
	endif
	int done = StorageUtil.GetIntValue(akActor, "SLOVE_StripZones", 0)
	int fresh = Math.LogicalAnd(aiZones, Math.LogicalNot(done))
	if fresh == 0
		return 0
	endif
	if !akActor.Is3DLoaded()
		return -1
	endif
	;written before the first call that can yield, so the same zone is never worked twice
	StorageUtil.SetIntValue(akActor, "SLOVE_StripZones", Math.LogicalOr(done, fresh))
	StorageUtil.FormListAdd(None, "SLOVE_StripActors", akActor, false)
	if abRedress
		StorageUtil.SetIntValue(akActor, "SLOVE_StripRedress", 1)
	else
		StorageUtil.SetIntValue(akActor, "SLOVE_StripRedress", 0)
	endif

	Form[] items = FindBlocking(akActor, fresh, afReach, aiKeepSlots)
	if !items ;NOT "== None": the DLL hands an empty list over as None
		return 0
	endif
	int taken = 0
	int i = 0
	while i < items.Length
		Form item = items[i]
		if item && akActor.IsEquipped(item)
			akActor.UnequipItem(item, false, true)
			StorageUtil.FormListAdd(akActor, "SLOVE_StripItems", item, false)
			taken += 1
		endif
		i += 1
	endwhile
	return taken
EndFunction

;Put back what Uncover took off this actor (when its redress flag says so and it
;still carries the item) and forget the actor's strip state. Returns the count.
Int Function Restore(Actor akActor) Global
	if !akActor
		return 0
	endif
	int put = 0
	if StorageUtil.GetIntValue(akActor, "SLOVE_StripRedress", 1) == 1 && !akActor.IsDead()
		int n = StorageUtil.FormListCount(akActor, "SLOVE_StripItems")
		int i = 0
		while i < n
			Form item = StorageUtil.FormListGet(akActor, "SLOVE_StripItems", i)
			if item && akActor.GetItemCount(item) > 0 && !akActor.IsEquipped(item)
				akActor.EquipItemEx(item, 0, false, false)
				put += 1
			endif
			i += 1
		endwhile
		;an equip does not draw on the player while the free camera is still up
		;(a scene end reached before the framework gave the camera back)
		if put > 0 && akActor == Game.GetPlayer() && Game.GetCameraState() == 3
			akActor.QueueNiNodeUpdate()
		endif
	endif
	StorageUtil.FormListClear(akActor, "SLOVE_StripItems")
	StorageUtil.UnsetIntValue(akActor, "SLOVE_StripZones")
	StorageUtil.UnsetIntValue(akActor, "SLOVE_StripRedress")
	StorageUtil.FormListRemove(None, "SLOVE_StripActors", akActor, true)
	return put
EndFunction

;Every actor: scene end, and a game load that finds no scene running.
Int Function RestoreAll() Global
	int put = 0
	int n = StorageUtil.FormListCount(None, "SLOVE_StripActors")
	while n > 0
		n -= 1
		Actor who = StorageUtil.FormListGet(None, "SLOVE_StripActors", n) as Actor
		if who
			put += Restore(who)
		endif
	endwhile
	StorageUtil.FormListClear(None, "SLOVE_StripActors") ;entries whose actor is gone
	return put
EndFunction
