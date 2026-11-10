# shortcuts

An [Ashita v4](https://www.ashitaxi.com/) port of the Windower [shortcuts](https://github.com/Windower/Lua/tree/live/addons/shortcuts)
addon, based on its version 2.9. Type actions the short way and it sends the full, quoted command with a sensible
target.

| You type | It sends |
|---|---|
| `/cure4` with nothing targeted | `/ma "Cure IV" <me>` |
| `/c4 bob` | `/ma "Cure IV" Bobby` |
| `/dia` or `//dia` with a mob targeted | `/ma "Dia" <t>` |
| `/savageblade` | `/ws "Savage Blade" <t>` |
| `/ws savage blade t` | `/ws "Savage Blade" <t>` |
| `/ma c4 stpc` | `/ma "Cure IV" <stpc>` |
| `/fire4` | `/ma "Fire IV" <t>` on BLM, `/ja "Fire IV" <t>` on SMN |
| `/wave` | `/wave <t>` with a target, `/wave <me>` without |
| `/check laz` | `/check Lazarus` |
| `/pcmd add laz` | `/pcmd add Lazarus` |

It works from the chat line and from macros.

## Install

1. Download `shortcuts-vX.Y.Z.zip` from the [latest release](https://github.com/Frankie-hz/shortcuts/releases/latest).
2. Extract it into your Ashita `addons` folder, so you end up with `addons/shortcuts/shortcuts.lua`.
3. In game, type `/addon load shortcuts`.

To load it every time, add `/addon load shortcuts` to `scripts/default.txt`.

## Commands

| Command | What it does |
|---|---|
| `/shortcuts debug` | Print every rewrite to the chat log. |
| `/shortcuts reload` | Reload `aliases.lua` and the action list. |
| `/shortcuts help` | List the commands in chat. |

## How it matches

- **Action names** ignore case, spaces and punctuation, and read numbers as roman numerals. `cure4`, `cure 4` and
  `Cure IV` all match Cure IV.
- **Aliases** in `aliases.lua` map a short word to a full name (`c4` is Cure IV, `ss` is Stoneskin). Edit the file and
  run `/shortcuts reload`.
- **Targets** can be a placeholder without brackets (`t`, `me`, `stpc`, `p1`), a server id, or part of a name. An exact
  name wins, then the closest name that starts with what you typed, then any name that contains it, within 50 yalms.
- **No target** picks `<t>` or `<me>` from what the action can target and what you have targeted.
- **Shared names** such as Fire IV (spell and blood pact) go to the one you can use. A `/ma`, `/ja` or `/ws` prefix
  picks between two usable ones.
- Chat commands (`/p`, `/l`, `/t`, `/say` and the rest) and fully written commands are left alone.

## Differences from the Windower addon

- Aliases replace only the action word. `/c4 la` targets a player whose name starts with "la". On Windower "la" also
  turned into Light Arts.
- Trusts are targeted by party slot (`<p2>`) instead of by name.
- `/shoot` and `/throw` get a default target the same way `/ra` does.
- With Pianissimo up, only songs that normally target yourself can go to a party member.
- Not ported: mounts, Monstrosity skills, names with Greek letters, and log files.

## Tests

The tests run the addon against a mock `AshitaCore` with [lupa](https://pypi.org/project/lupa/), outside the game.

```bash
pip install lupa
python tests/run.py
```

## Credits

- **Byrthnoth** wrote the original [shortcuts](https://github.com/Windower/Lua/tree/live/addons/shortcuts) addon for
  Windower. This port follows its matching, targeting and disambiguation rules, and keeps its default aliases and
  command lists.
- **ThornyFFXI**, whose [Shorthand](https://github.com/ThornyFFXI/Shorthand) plugin showed how to send a server id
  target so the client accepts it.
- **The Ashita team** for [Ashita v4](https://www.ashitaxi.com/).

This port is not affiliated with or endorsed by Byrthnoth or the Windower team.

## License

BSD 3-Clause, the same license as the original addon. See [LICENSE](LICENSE).
