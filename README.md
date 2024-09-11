ArtillerySmartClusteringRemote
======================================

FORK
----
Forked from [Advanced Artillery Remotes (Continued)](https://github.com/azaghal/Factorio-AdvancedArtilleryRemotesContinued)
This fork removes the discovery remote and focuses only on the cluster remote, changing it to use a clustering algorithm to assure optimized destruction.
Research and recipe for remote is also updated.

About Original Mod Features
-----

*Advanced Artillery Remotes* introduces additional artillery remotes to the game, allowing the player to use artillery for exploration (map discovery) purposes, as well as for easier destruction (through carpet bombing) of alien lifeforms.


Features
--------

### Artillery cluster remotes

Artillery cluster remotes target nearby spawners and/or worms and blanket them with artillery fire.

Multiple types of artillery cluster remotes are made available, one for each artillery ammo category. This way, if the 3rd-party mod implements dedicated ammo category for its artillery shells, it is possible to pick the best-suited artillery for the task. One example of such usage would be the [Atomic Artillery](https://mods.factorio.com/mod/AtomicArtillery) mod coupled with the [Atomic Artillery Remote](https://mods.factorio.com/mod/AtomicArtilleryRemote) mod, which allows player to pick whether the atomic or regular (vanilla) artillery should be used for carpet-bombing the enemy simply by using a different artillery cluster remote type.

Each artillery cluster remote type has its own colour assigned to the item icon, making it easier to distinguish between them. In some cases colour is assigned statically (for well-known ammo categories), while in others the mod assigns a random colour from a pre-defined set of colours.

**NOTE:** At time of this writing, up to six different ammo category (artillery cluster remote) types are supported by the mod. See the *Known issues* section below.

After targeting a specific area, artillery cluster remotes locates all enemy spawners and worms within a certain (configurable) radius, calculates the optimal pattern of impacts to enagage all targets, and requests bombardment of the area. Artillery targets are designated in a manner that will minimize the use of artillery shells by calculating the best clusters of enemy targets.

Behaviour of artillery cluster remotes can be tweaked slightly through mod settings - such as picking mode of operation (spawners only vs spawners + worms), customising target acquisition radius, or overriding ammo damage radii. For more details please see the in-game setting descriptions.

| Example usage with vanilla artillery shells (from original mod)                                   |
|---------------------------------------------------------------------------------------------------|
| ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/cluster-remote.gif) |


Contributions
-------------

Should you come upon bugs, or have features and ideas on how to make the mod better, please do not hesitate to voice your feedback either through mod portal discussion page, or through project's issue tracker. Pull requests for implementing new features and fixing encountered issues are always welcome.


Known issues
------------

-   ~~Cluster targeting is suboptimal - less artillery shots could be used to destroy enemy within the same area. This is partially done in order to reduce complexity of comuputation, and partially in order not to make cluster targeting too overpowered - artillery cluster remotes save some time and provide convenience at the expense of increased resource usage.~~
-   **Not entirely fixed, but much better, now.** ~~Cluster targeting does not always manage to damage all enemy entities in an area. This is a consequence on how the damage radius is calculated for individual ammo categories. This is done by using same algorithm that shows the player damage/explosion area when holding the remote, which will often include visual effects such as smoke etc. However, this can be somewhat negated by using the mod settings to specify custom damage radius for ammo categories (see in-game mod settings for more details).~~
-   Distinct artillery cluster remotes can only be created per ammo category - if a mod introduces additional artillery shells (which have different damage radius compared to vanilla artillery shells) that belong to the default artillery shell ammo category, then only one artillery cluster remote type is added by the mod. The reason for this is that target (flare) spawning (created by the remote) revolves around ammo categories, and it is not possible to tell the game to use only a particular ammo type unless it belongs in its own category.
-   Only up to six artillery cluster remote types can exist in any given game. There is no real limitation behind this in the code, except that the six corresponding colours have been generated statically using six-tone colour palette generator algorithm. Should a need arise, this mod can easily be updated to support more types of artillery cluster remotes.
-   ~~Artillery cluster remotes are researched as part of vanilla game *Artillery* research instead of making them available as part of a particular artillery shell type technology research. This is done primarily to avoid messing too much with the 3rd-party mod technology trees.~~
-   When using [Shortcuts for 1.1](https://mods.factorio.com/mod/Shortcuts-ick) mod, vanilla artillery cluster remote will not be hidden from the game. This is a consequence of temporary fix for crash in *Shortcuts for 1.1* mod, version 1.1.27.


Roadmap
-------

-   Create smart unit-leading barrage option that predicts travel time of shells based on loaded cannons in range, and current motion of enemy. Possible add addition shells to saturate radius around predicted intersect location


Credits
-------

This is a continuation/fork of [Advanced Artillery Remotes (Continued)]([https://mods.factorio.com/mod/AdvArtilleryRemotes](https://github.com/azaghal/Factorio-AdvancedArtilleryRemotesContinued)) mod, implemented and maintained by [azaghal](https://mods.factorio.com/user/azaghal). Many thanks to the original author for both implementing that mod, and for releasing it under a Free (as in Freedom) license, thus making it possible to learn from it and make improvements.


License
-------

All code, documentation, and assets implemented as part of this mod are released under the terms of MIT license (see the accompanying `LICENSE` file), with the following exceptions:

-   [build.sh (factorio_development.sh)](https://code.majic.rs/majic-scripts/), by Branko Majic, under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
-   `assets/artillery-target.xcf`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `assets/artillery-targeting-remote.xcf`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `graphics/artillery-target.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `graphics/icon/artillery-cluster-remote-shells.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `graphics/icon/artillery-discovery-remote-radar.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `graphics/icon/artillery-remote-target.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
