Advanced Artillery Remotes (Continued)
======================================


Introduction
------------

| ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/cluster-remote.gif) | ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-30.gif) | ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-360.gif) |
|----------------|-----------------------------------|------------------------------------|
| Cluster remote | Discovery remote, arc radius = 30 | Discovery remote, arc radius = 360 |

**Advanced Artillery Remotes Continued** adds two additional artillery remotes to the game:

-   *Artillery Cluster Remote*, which targets nearby spawners and/or worms and blankets them with artillery fire.

-   *Artillery Discovery Remote*, which lays down artillery fire in an arc, useful for exploring the map.

Both remotes default to using base (vanilla) game artillery shell ammo category (`artillery-shell`). This should help prevent firing of atomic artillery shells when using the remotes. Take note that it is up to mods that implement additional types of artillery shells to place them into separate ammo category.

A number of settings are provided for controlling wheter only spawners or both spawners and worms should be targeted, as well as allowing some tweaking in terms of how large of an area should be bombarded. For more details please see the in-game setting descriptions.


History
-------

Original mod ([Advanced Artillery Remotes](https://mods.factorio.com/mod/AdvArtilleryRemotes)) was implemented and maintained by [Dockmeister](https://mods.factorio.com/user/Dockmeister).

When Factorio 1.1 came out, the mod stopped working, and after a period of inactivity a fork was created by [azaghal](https://mods.factorio.com/user/azaghal) under name [Advanced Artillery Remotes Continued](https://mods.factorio.com/mod/AdvArtilleryRemotes) with necessary fixes (a mere bump in Factorio version in info file was sufficient).


License
-------

All code, documentation, and assets implemented as part of this mod are released under the terms of MIT license (see the accompanying `LICENSE` file), with the following exceptions:

-   [build.sh (factorio_development.sh)](https://code.majic.rs/majic-scripts/), by Branko Majic, under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
-   `assets/artillery-targeting-remote.xcf`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `artillery-cluster-remote-shells.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `artillery-discovery-remote-radar.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `artillery-remote-target.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
