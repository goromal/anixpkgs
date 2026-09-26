# play

Play GameCube and PlayStation 2 games with cloud-synced memory cards.

Uses Dolphin or PCSX2 and the shared Sunshine game catalog. Run play setup-ps2
to select a PS2 BIOS and map the controller during a Moonlight session.
PS2 cards are synced through ~/games/ps2/memcards; BIOS, settings, and save states stay local.
Use Sunset Stop for PCSX2 before disconnecting. Force quit can interrupt game saves.
Interrupted transfers leave recovery instructions in ~/.local/state/play/*.pending.

## Usage

```bash
usage: play GAME|setup-ps2

Play a game. Your options:
      zelda	Legend of Zelda: Collector's Edition
      windwaker	The Wind Waker
      twilight	Twilight Princess
      melee	Super Smash Bros. Melee
      sunshine	Super Mario Sunshine
      kh2	Kingdom Hearts II
      jak2	Jak II
      jak3	Jak 3
      setup-ps2  Configure the PS2 BIOS, controller, and memory cards.

```

