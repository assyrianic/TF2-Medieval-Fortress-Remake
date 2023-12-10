
# Medieval Fortress

Remake of a previous medieval fortress mod.
The intent is to spice up TF2's medieval mode since it hasn't gotten an update in... forever ago!

Using libmodsys as a modular framework, (as of this writing) the mod provides a currency, HUD, leveling, mana, and spells system.

(as of this writing) the mod is in development.


### How do I get set up?

* Dependencies: [TF2Items](https://builds.limetech.io/?project=tf2items), [LibModSys](https://github.com/assyrianic/LibModSys), ConfigMap, MoreColors (MoreColors & ConfigMap are part of repo).
* Optional Dependencies: [TF2Attributes](https://github.com/FlaminSarge/tf2attributes), [SteamTools](https://forums.alliedmods.net/showthread.php?t=170630)

### Who do I talk to?

* **Lead Developer:** *Nergal the Ashurian/Assyrian* - https://forums.alliedmods.net/member.php?u=176545

### Contribution Rules
#### Code Format:
* Use New sourcepawn syntax (sourcemod 1.7+).
* Statements that require parentheses (such as 'if' statements) should have each side of the parentheses spaced out with the beginning parens touching the construct keyword, e.g. `construct( code/expression )`.
* Single line comments that convey a message must have 3 slashes: `///`.
* Multi-line comments that convey a message should have an extra beginning star: `/**`.
* Properties, functions, & methods should have the beginning `{` brace in K&R C style, for example: `ret func() {`.
* Local variable names should be in snake_case.
* Property names must have a single-letter prefix of their type.
* Functions, methods, methodmaps, enums, enum values, must be named in PascalCase. Pascal_Case is also acceptable.
* Enum values used as flags may be upper-case.
