Scriptname FNIS Hidden
{COMPILE-TIME STUB - not shipped, never runs, never called by SLO VE.

 Classic SexLab's sslSystemConfig.psc calls FNIS.GetMajor / VersionCompare /
 IsGenerated. SLO VE pulls that file into type-checking only transitively -
 SLOVE_* declares "SexLabFramework Property SexLab", SexLabFramework declares
 "sslSystemConfig property Config", and the compiler then has to resolve
 sslSystemConfig, which needs an FNIS header to exist.

 Nothing in SLO VE references FNIS: the compiled .pex files contain no FNIS or
 sslSystemConfig reference at all. At runtime the real FNIS.pex is what the game
 loads (SexLab classic requires FNIS anyway), and global calls resolve lazily by
 name - so these bodies never execute. This stub exists purely so the classic
 build does not depend on an FNIS source tree being installed at a fixed path.

 Signatures copied from FNIS Behavior SE 7.6 fnis.psc - keep in sync.}

bool function IsGenerated() global
	return true
endFunction

int function VersionCompare( int iCompMajor, int iCompMinor1, int iCompMinor2, bool abCreature = false ) global
	return 0
endFunction

int function GetMajor( bool abCreature = false ) global
	return 0
endFunction
