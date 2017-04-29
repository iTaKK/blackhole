# TF2 Black Hole Rockets

[![IMAGE ALT TEXT HERE](http://img.youtube.com/vi/nPqw6mheaf4/0.jpg)](http://www.youtube.com/watch?v=nPqw6mheaf4)

## Description
This plugin will create a black hole on rocket detonation.

## Requirements
```
Plugin for Team Fortress 2
Requires Sourcemod 1.8+ and Metamod 1.10+
```

## Convar settings
```
sm_blackhole_enabled - Enables/Disables Black hole rockets.
sm_blackhole_radius - Radius of pull.
sm_blackhole_inner_radius - How close player is before doing damage/teleported them?
sm_blackhole_pullforce - What should the pull force be?
sm_blackhole_damage - How much damage should the blackholes do per second?
sm_blackhole_duration - How long does the black hole last?
sm_blackhole_shake - When players are in radius of the black hole, their screens will shake
sm_blackhole_critical - If set to 1, black hole rockets are only created on critical shots.
sm_blackhole_ff - If set to 1, black hole rockets will effect teammates.
```

## Commands
```
sm_bh <client> <1:ON | 0:OFF> - Turn on Black Hole rockets for anyone.
sm_explosivebullets - Same as sm_bh
sm_bhme - Turn on black hole rockets for yourself.
sm_blackholeme - Same as sm_bhme
sm_setbh - Set the end point location for blackhole, blackhole will teleport instead of doing damage.
sm_resetbh - Reset the end point location for blackhole, blackhole will start doing damage.
```

## Installation
```
1. Place blackhole.smx to addons/sourcemod/plugins/
3. Place blackhole.cfg to cfg/sourcemod/ and edit your convars to fit your needs
```