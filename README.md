# Introduction

| ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/cluster-remote.gif) | ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-30.gif) | ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-360.gif) |
|----------------|-----------------------------------|------------------------------------|
| Cluster remote | Discovery remote, arc radius = 30 | Discovery remote, arc radius = 360 |

**Advanced Artillery Remotes Continued** adds two additional artillery
remotes to the game:

- *Artillery Cluster Remote*, which finds nearby spawners and worms
  and lays down a carpet of artillery flares.

- *Artillery Discovery Remote*, which spawns flares in an arc to
  assist in discovering new chunks.

# Settings

## General

**Verbose** *(default: Enabled)*<br/>
  If enabled, output detailed information about fired shells and
  targets to the console when using the remotes.

## Advanced cluster remote

**Cluster mode** *(default: Spawners only)*<br/>
  Choose whether to target *only* spawners or *both* spawners and
  worms.

**Cluster radius** *(default: 32)*<br/>
  Radius in tiles.

**Merge radius** *(default: 7)*<br/>
  The mod tries to merge targets into one flare to reduce the number
  of artillery shells needed. Higher number means more potential
  targets get merged into one flare. Numbers between 6 and 8 work
  well.

## Advanced discovery remote

**Discovery arc radius** *(default: 30)*<br/>
  Arc radius (in degrees) in which artillery rounds should be fired
  from the artillery. Setting the value to 360 degrees would launch an
  artillery flare in every direction around the artillery.

**Discovery angle width** *(default: 40)*<br/>
  Distance between impact points for artillery flares. Smaller width
  results in better coverage at the expense of additional artillery
  shells. Default value should be sufficient for most use-cases.

# History

Original mod ([Advanced Artillery Remotes](https://mods.factorio.com/mod/AdvArtilleryRemotes))
was implemented and maintained by [Dockmeister](https://mods.factorio.com/user/Dockmeister).

When Factorio 1.1 came out, the mod stopped working, and after a
period of inactivity a fork was created
by [azaghal](https://mods.factorio.com/user/azaghal) under name
[Advanced Artillery Remotes Continued](https://mods.factorio.com/mod/AdvArtilleryRemotes) with
necessary fixes (a mere bump in Factorio version in info file was
sufficient).
