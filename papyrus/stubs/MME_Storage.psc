Scriptname MME_Storage Hidden
{COMPILE-TIME STUB - not shipped, never runs. The real MME_Storage.pex comes
 from Milk Mod Economy at runtime; global calls resolve lazily by name, so
 SLOVE_Director links against these signatures without importing MME's full
 source tree (which chases SOS -> Devious Devices -> FNIS sources).
 Signatures copied from Milk Mod Economy MME_Storage.psc - keep in sync.}

float function getMilkCurrent(actor akActor) global
	return 0.0
endfunction

float function getMilkMaximum(actor akActor) global
	return 0.0
endfunction

function changeMilkCurrent(actor akActor, float Delta, bool enforceMaxValue) global
endfunction
