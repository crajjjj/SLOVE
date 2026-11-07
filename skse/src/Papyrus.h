#pragma once

// The Papyrus natives SLOVE.dll binds. The scripts call them on every scene, so
// SLO VE needs the DLL (the settings menu on top of it stays optional):
//   SLOVE_PPA             the Accurate Penetration readings and the thrust watch (PPA.h)
//   SLOVE_Hentairim_Tags  the label engine's classifier (core/Labels.h)
// A native's signature never changes once released: the VM rejects a call whose
// argument count differs, and every compiled script would break. A new option
// is a new native.

namespace Papyrus
{
	bool Register(RE::BSScript::IVirtualMachine* a_vm);
}
