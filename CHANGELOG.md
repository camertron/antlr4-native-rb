## 2.2.0
* Use underscores in gem names instead of dashes (@dsisnero, #14)

## 2.1.0
* Upgrade to ANTLR 4.10 (#13, @maxirmx)

## 2.0.1
* Address segfaults for enhanced stability (#11, @maxirmx)
  - Return a copy of children from `getChildren()` calls instead of a reference.
  - Add `Return().keepAlive()` to several key methods to prevent the ANTLR parser, tokens, lexer, etc from being destroyed if the Ruby interpreter holds a reference to them.

## 2.0.0
* Upgrade to Rice v4 (#8, @lutaml)

## 1.1.0
* Add support for MS Windows (#2, @zakjan)
* Return values from visit methods (#3, @zakjan)
* Support optional tokens in rules (#4, @zakjan)
* Add root method to ParserProxy (#5, @zakjan)
  - Designed to enable passing the root node to Visitor#visit, which is more consistent with ANTLR patterns.

## 1.0.2
* Fix terminal node declaration.

## 1.0.1
* Include ANTLR jar in gem release.

## 1.0.0
* Birthday!
