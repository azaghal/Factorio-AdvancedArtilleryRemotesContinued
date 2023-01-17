Advanced Artillery Remotes (Continued)
======================================


About
-----

*Advanced Artillery Remotes* introduces additional artillery remotes to the game, allowing the player to use artillery for exploration (map discovery) purposes, as well as for easier destruction (through carpet bombing) of alien lifeforms.


Features
--------


### Artillery discovery remote

Artillery discovery remote lays down artillery fire in an arc, making it useful for discovering the unexplored parts of the map that border your main base or outposts.

Artillery discovery remote uses the base (vanilla) game artillery shell ammo category (`artillery-shell`) for targeting purposes. This way if you have additional mods that introduce additional artillery shells (with their own category), no expensive ammunition will be wasted for a simple exploration task.

A number of settings pertaining to artillery discovery remote are made available for tweaking, such as arc angle or density (radial distance) between individual shots fired. For more details please see the in-game settings descriptions.

| Example usage with arc radius set to 30 | Example usage with arc radius set to 360 |
|-----------------------------------------|------------------------------------------|
|![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-30.gif) | ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/discovery-remote-arc-radius-360.gif) |


### Artillery cluster remotes

Artillery cluster remotes target nearby spawners and/or worms and blanket them with artillery fire.

Multiple types of artillery cluster remotes are made available, one for each artillery ammo category. This way, if the 3rd-party mod implements dedicated ammo category for its artillery shells, it is possible to pick the best-suited artillery for the task. One example of such usage would be the [Atomic Artillery](https://mods.factorio.com/mod/AtomicArtillery) mod coupled with the [Atomic Artillery Remote](https://mods.factorio.com/mod/AtomicArtilleryRemote) mod, which allows player to pick whether the atomic or regular (vanilla) artillery should be used for carpet-bombing the enemy simply by using a different artillery cluster remote type.

Each artillery cluster remote type has its own colour assigned to the item icon, making it easier to distinguish between them. In some cases colour is assigned statically (for well-known ammo categories), while in others the mod assigns a random colour from a pre-defined set of colours.

**NOTE:** At time of this writing, up to six different ammo category (artillery cluster remote) types are supported by the mod. See the *Known issues* section below.

After targeting a specific area, artillery cluster remotes locate all enemy spawners and worms within a certain (configurable) radius, and request bombardment of the area. Artillery targets are designated in a manner that will reduce the use of artillery shells by trying to target multiple enemy structures with a single shot. The algorithm has not been designed for optimal placement, though, and some wastage of artillery shells can be expected.

Behaviour of artillery cluster remotes can be tweaked slightly through mod settings - such as picking mode of operation (spawners only vs spawners + worms), or customising density of shots fired against the enemy by ammo category/artillery cluster remote type. For more details please see the in-game setting descriptions.

| Example usage with vanilla artillery shells                                                       |
|---------------------------------------------------------------------------------------------------|
| ![](https://azaghal.github.io/Factorio-AdvancedArtilleryRemotesContinued/demo/cluster-remote.gif) |


Contributions
-------------

Should you come upon bugs, or have features and ideas on how to make the mod better, please do not hesitate to voice your feedback either through mod portal discussion page, or through project's issue tracker. Pull requests for implementing new features and fixing encountered issues are always welcome.


Known issues
------------

-   Cluster targeting is suboptimal - less artillery shots could be used to destroy enemy within the same area. This is partially done in order to reduce complexity of comuputation, and partially in order not to make cluster targeting too overpowered - artillery cluster remotes save some time and provide convenience at the expense of increased resource usage.
-   Cluster targeting does not always manage to damage all enemy entities in an area. This is a consequence on how the damage radius is calculated for individual ammo categories. This is done by using same algorithm that shows the player damage/explosion area when holding the remote, which will often include visual effects such as smoke etc. However, this can be somewhat negated by using the mod settings to specify custom damage radius for ammo categories (see in-game mod settings for more details).
-   Distinct artillery cluster remotes can only be created per ammo category - if a mod introduces additional artillery shells (which have different damage radius compared to vanilla artillery shells) that belong to the default artillery shell ammo category, then only one artillery cluster remote type is added by the mod. The reason for this is that target (flare) spawning (created by the remote) revolves around ammo categories, and it is not possible to tell the game to use only a particular ammo type unless it belongs in its own category.
-   Only up to six artillery cluster remote types can exist in any given game. There is no real limitation behind this in the code, except that the six corresponding colours have been generated statically using six-tone colour palette generator algorithm. Should a need arise, this mod can easily be updated to support more types of artillery cluster remotes.
-   Artillery cluster remotes are researched as part of vanilla game *Artillery* research instead of making them available as part of a particular artillery shell type technology research. This is done primarily to avoid messing too much with the 3rd-party mod technology trees.


Credits
-------

This is a continuation/fork of the original [Advanced Artillery Remotes](https://mods.factorio.com/mod/AdvArtilleryRemotes) mod, implemented and maintained by [Dockmeister](https://mods.factorio.com/user/Dockmeister). Many thanks to the original author for both implementing the original mod, and for releasing it under a Free (as in Freedom) license, thus making it possible to learn from it and make improvements.


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
