# Đĩa Bay Thép round 2 on the client (2026-11-13)

Server: `battle-squad` `docs/contracts/ufo-skills.md` (migration 113), spec
`docs/specs/2026-11-13-boss-dia-bay-thep.vi.md` "Vòng 2". The client only replays the events; this
note is what it draws and why.

## Turret

- Art: `assets/bosses/steel_robot/turret/` (`Art.boss_turret()`); the body frames have no cannon.
- `BossBody` draws the turret over the body at the mount of the frame shown (turret.json
  `bodyFrames`: the hurt's tilt), turned by `TurretModel` (art frame: 0° forward, + down, mirrored
  facing left), clamped to 10..120° (the nearer limit), rest 20°.
- A boss shot plays a plan on the replay's clock (`match_screen._drive_turret()`,
  `TurretModel.cues()`): it faces the side the skill leaves from (the events' pivot), turns
  `TURN_SEC` (0.2 s, ease out) before each beam onto its `to` and before each projectile that leaves
  from the turret along its first step, holds hot over the beams, rests `REST_AFTER` s after.
- Its picture follows the body animation (`TurretModel.state_for()`): cast = charge_0, recoil_0 on
  the peak (muzzle flash at both tips), recoil_1 (smoke); burst = charge_0, charge_1, hot (held
  over every beam: `BossAnim.action_for()` holds the peak until the last beam ends). A shot with no
  turret aim (Bom mù) keeps it idle.
- `muzzle_position()` = the turned mid tip (follows the bob, lean, hurt tilt); a projectile the
  turret fires leaves from there (`ShotPlayer.muzzle` = `tip_toward()` its first step).
  Server `turret.reach` (0.4244 H) equals the art's mid tip (29.27 units × 1.45 / 100); the client
  uses the art.

## Skills

- Tia laze nghiền (beam pattern `each`): `TurretBeamsFx`, one beam at a time from the tip (every
  frame) to the member, through terrain; charge dot, flicker, bolts, impact flash; map framed.
- Mưa đạn pháo (rain + `signalKind`): projectile 0 (`signal_flare`, a red canister with sparks) from
  the tip; RainFx follows the drawn flare (red light, smoke), lands at the `flare` event and lies
  there (canister blinking, red smoke column) until the rain is over; `saucer_missile` (outlined,
  red nose, fins, flame) fall nose down from the top.
- Bom mù (global + `flash`): `flash_flare` drawn from the dome top (the turret cannot point up),
  easing onto the server path (`UnitShell.lead`); the `global` event's `flash` = a full-screen white
  flash for everyone (`BossGlobal.FlashFx`).

## Blind

`BlindOverlay`: on while I am alive and have `blind` (from the status event at the flash until the
server ticks it at the end of my next own turn), whatever turn it is. The screen is white except a
clear circle (radius 1.5 × my figure's height on screen, soft edge) round my own unit, following it
through the camera; nobody else's circle is drawn. Others see the blindfold (StatusLook) only.
