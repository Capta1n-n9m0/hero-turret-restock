# Hero Turret Restock

A Factorio 2.1 mod for [HeroTurretRedux](https://mods.factorio.com/mod/HeroTurretRedux) (or
[HeroTurretsReduxFork](https://mods.factorio.com/mod/HeroTurretsReduxFork)). One shortcut-bar button puts ranked
hero turrets that sit in logistic storage back on the defence wall.

Mod portal: <https://mods.factorio.com/mod/hero-turret-restock>

## The problem

When a wall is moved or rebuilt, the old turrets are picked up and plain ones are placed. Picked-up turrets keep
their rank as items (`hero-turret-<rank>-for-<turret>`), nothing ever asks for them again, and they pile up in
storage while the wall is manned by plain turrets.

## What the button does

1. Finds every turret of your force that has hero ranks, on every surface, skipping turrets marked for
   deconstruction.
2. Assigns each one to the first stationary roboport network whose **construction** area covers it (walls are
   usually outside the logistic area but inside construction range). Personal roboports are ignored.
3. Per network, base turret and quality: sorts the ranked items in storage from the highest rank down, and the
   placed turrets from the lowest rank up (among equal ranks, the one with the most kills first, so the turrets that
   fight most get the best replacements). The two lists are paired while the stock rank is higher than the placed
   rank.
4. Every pair becomes a normal upgrade order. Construction robots bring the ranked turret, swap it in and take the
   old one back to storage.
5. Reports in chat how many turrets were marked per type and rank, and how much ranked stock could not be used.

Turrets already marked for upgrade reserve their item, so pressing the button again before the robots are done
marks nothing new. Orders can be cancelled like any other upgrade order.

## Design notes

- **Best stock to worst placed, directly.** Upgrading everything by one rank and passing the freed turrets down
  ends with the same ranks on the wall but needs many more swaps. With direct pairing a removed turret never
  outranks what is left in storage, so one press is enough, and storage ends up holding plain turrets whenever the
  wall has enough low-ranked positions.
- **Robots, not a script swap.** The mod never destroys or creates a turret. The game's own upgrade path keeps item
  accounting honest and avoids replacing a turret in the middle of its shooting update.
- **Kill counter.** HeroTurretRedux's kill counter must be `Fuzzy` (the default): a picked-up ranked turret is then
  a plain item that robots can use for an upgrade, and the built turret gets the kills of its rank. With `Exact`,
  picked-up turrets become `-with-tags` items, which robots don't use for upgrade orders.
- A ranked pile can remain when there are more ranked turrets than lower-ranked wall positions; what remains is
  always the bottom of the pool.

## Remote interface

```lua
remote.call("hero-turret-restock", "restock", force_name)  -- same as the button; returns the number of turrets marked
```

`force_name` defaults to `"player"`.

## Requirements

Factorio 2.1 and HeroTurretRedux or HeroTurretsReduxFork (both optional dependencies; the mod does nothing without
one of them).

## Development

The mod lives in `mod/hero-turret-restock/`. Its tests are a
[FactorioTest](https://github.com/GlassBricks/FactorioTest) suite in `mod/hero-turret-restock/tests/` (pairing
rules, quality, and construction robots carrying out a real upgrade); they load only when the `factorio-test` mod is
active, so they never run in a normal game. They work on their own surface and force, so they can also run on a
loaded save. Run them with the FactorioTest CLI, for example

```
npx -p factorio-test-cli factorio-test run --mod-path mod/hero-turret-restock --mods HeroTurretRedux
```

`tests/autotest.json` lists the mod sets the suite is run with before a release.

## License

MIT, see `LICENSE`.
